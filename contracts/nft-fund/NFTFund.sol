// SPDX-License-Identifier: MIT

/*
    ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
    ░    ░░░░░   ░        ░░           ░        ░░░░░░░░░░░░░░░░░░░░░░░░░░   ░
    ▒  ▒   ▒▒▒   ▒   ▒▒▒▒▒▒▒▒▒▒▒   ▒▒▒▒▒   ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒   ▒
    ▒   ▒   ▒▒   ▒   ▒▒▒▒▒▒▒▒▒▒▒   ▒▒▒▒▒   ▒▒▒▒▒▒▒   ▒▒   ▒   ▒   ▒▒▒▒▒▒▒▒   ▒
    ▓   ▓▓   ▓   ▓       ▓▓▓▓▓▓▓   ▓▓▓▓▓       ▓▓▓   ▓▓   ▓▓   ▓▓   ▓▓   ▓   ▓
    ▓   ▓▓▓  ▓   ▓   ▓▓▓▓▓▓▓▓▓▓▓   ▓▓▓▓▓   ▓▓▓▓▓▓▓   ▓▓   ▓▓   ▓▓   ▓  ▓▓▓   ▓
    ▓   ▓▓▓▓  ▓  ▓   ▓▓▓▓▓▓▓▓▓▓▓   ▓▓▓▓▓   ▓▓▓▓▓▓▓   ▓▓   ▓▓   ▓▓   ▓  ▓▓▓   ▓
    █   ██████   █   ███████████   █████   █████████      █    ██   ██   █   █
    ██████████████████████████████████████████████████████████████████████████

*/


pragma solidity ^0.8.12;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract NFTFund is 
    ERC721,
    ERC721Enumerable,
    ReentrancyGuard,
    Pausable,
    Ownable
{
    using Counters for Counters.Counter;
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    Counters.Counter private _tokenIdCounter;

    struct FundEntity {
        uint256 id;
        string name;
        uint256 creationTime;
        uint256 numberOfShares;
        uint256 rewardsDistributed;
        bool autoCompound;
    }

    mapping(uint256 => FundEntity) private _funds;

    uint256 public totalShareCount = 0;

    uint public fee = 0; // per 1000
    address public feeCollector;
    // Deposit Token
    address public rewardToken;
    // Purchase Tokens
    address public purchaseToken;
    uint256 public purchaseTokenPrice; // In decimals
    uint256 public newInvestments = 0;

        // Statistic Variables
    uint256 public totalInvestment;
    uint256 public totalRewardsDistributed;
    uint256 public rewardAmountDeposited = 0;

    event FundInvestment(
        address indexed account,
        uint256 indexed fundId,
        uint256 amount
    );

    modifier onlyFundOwner() {
        address sender = _msgSender();
        require(
            sender != address(0),
            "Funds: Cannot be from the zero address"
        );
        require(
            isOwnerOfFunds(sender),
            "Funds: No Fund owned by this account"
        );
        _;
    }

   modifier checkPermissions(uint256 _fundId) {
        address sender = _msgSender();
        require(fundExists(_fundId), "Funds: This fund doesn't exist");
        require(
            isApprovedOrOwnerOfFund(sender, _fundId),
            "Funds: You do not have control over this Fund"
        );
        _;
    }

    modifier checkPermissionsMultiple(uint256[] memory _fundIds) {
        address sender = _msgSender();
        for (uint256 i = 0; i < _fundIds.length; i++) {
            require(
                fundExists(_fundIds[i]),
                "Funds: This fund doesn't exist"
            );
            require(
                isApprovedOrOwnerOfFund(sender, _fundIds[i]),
                "Funds: You do not control this Fund"
            );
        }
        _;
    }

    modifier verifyName(string memory fundName) {
        require(
            bytes(fundName).length > 1 && bytes(fundName).length < 32,
            "Funds: Incorrect name length, must be between 2 to 31"
        );
        _;
    }


    constructor(uint _fee) ERC721("NFTFund", "NFTF") {
        address sender = _msgSender();
        fee = _fee;
        feeCollector = sender;
        _pause();
        _tokenIdCounter.increment();
    }

/*
    TODO we need to add minimun holding time before distributions are allowed for a specific holder
    // set minimum share holding time in order to get rewards
    function setMinShareHoldingTime(uint256 _time) external onlyOwner {
        minShareHoldingTime = _time;
    }
*/

    // Deposit to Purchase Methods
    function editPurchaseToken(address _tokenAddress) external onlyOwner {
        purchaseToken = _tokenAddress;
    }

    function editPurchasePrice(uint256 _price) external onlyOwner {
        purchaseTokenPrice = _price;
    }

    // Deposit to Share Rewards Methods
    function setDepositToken(address _tokenAddress) external onlyOwner {
        rewardToken = _tokenAddress;
    }

    function setFeeCollector(address _address) external onlyOwner {
        feeCollector = _address;
    }

    function setFee(uint _fee) external onlyOwner {
        fee = _fee;
    }

    // Withdrawals
    function withdrawToOwnerNewInvestments() external onlyOwner {
        IERC20(purchaseToken).safeTransfer(owner(), newInvestments);
        newInvestments = 0;
    }

    function withdrawToOwner(address _token, uint256 _amount) external onlyOwner {
        IERC20(_token).safeTransfer(owner(), _amount);
    }

    function getSharePrice() public view returns (uint256) {
        return purchaseTokenPrice;
    }

    function mintFund(uint256 _shareCount, string memory _fundName)
        external
        nonReentrant
        whenNotPaused
        verifyName(_fundName)
    {
        address sender = _msgSender();

        uint256 _totalPrice = getSharePrice();
        uint256 _totalAmount = _totalPrice * _shareCount;

        IERC20(purchaseToken).safeTransferFrom(
            sender,
            address(this),
            _totalAmount
        );

        uint256 currentTime = block.timestamp;

        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();

        // create a fund
        _funds[tokenId] = FundEntity({
            id: tokenId,
            name: _fundName,
            creationTime: currentTime,
            numberOfShares: _shareCount,
            rewardsDistributed: 0,
            autoCompound: false
        });

        // Assign the Fund to this account
        _mint(sender, tokenId);        

        totalInvestment = totalInvestment.add(
            _shareCount.mul(purchaseTokenPrice)
        );

        totalShareCount = totalShareCount.add(_shareCount);
        newInvestments = newInvestments.add(
            purchaseTokenPrice.mul(_shareCount)
        );

        emit FundInvestment(
            sender,
            tokenId,
            _shareCount
        );
    }

    function _burn(uint256 _tokenId)
        internal
        override(ERC721)
    {
        totalShareCount = totalShareCount.sub(_funds[_tokenId].numberOfShares);
        delete _funds[_tokenId];
        super._burn(_tokenId);
    }

    function fundExists(uint256 _fundId) private view returns (bool) {
        require(_fundId > 0, "Funds: Id must be higher than zero");

        if (_funds[_fundId].id != 0) return true;

        return false;
    }

    function getFundIdsOf(address account)
        public
        view
        returns (uint256[] memory)
    {
        uint256 numberOfFunds = balanceOf(account);
        uint256[] memory fundIds = new uint256[](numberOfFunds);
        for (uint256 i = 0; i < numberOfFunds; i++) {
            uint256 fundId = tokenOfOwnerByIndex(account, i);
            require(
                fundExists(fundId),
                "Funds: This fund doesn't exist"
            );
            fundIds[i] = fundId;
        }
        return fundIds;
    }

    function getFundsByIds(uint256[] memory _fundIds)
        external
        view
        returns (FundEntity[] memory)
    {

        FundEntity[] memory funds = new FundEntity[](
            _fundIds.length
        );

        for (uint256 i = 0; i < _fundIds.length; i++) {
            require(
                fundExists(_fundIds[i]),
                "Funds: This fund doesn't exist"
            );
            funds[i] = _funds[_fundIds[i]];
        }

        return funds;
    }

    function depositRewards(uint256 _amount) external {
        address sender = _msgSender();
        uint256 _addedRewards = 0;
        // deduct the fee
        _addedRewards = (_amount * (1000 - fee)) / 1000;

        // Stats
        rewardAmountDeposited += _addedRewards;
        // Transfer the rewards
        IERC20(rewardToken).safeTransferFrom(
            sender,
            address(this),
            _addedRewards
        );
        // Transfer the fee
        IERC20(rewardToken).safeTransferFrom(
            sender,
            feeCollector,
            (_addedRewards / (1000 - fee)) * fee
        );
    }

   function distributeRewards(
        uint256 _rewardAmount,
        address _rewardToken
    ) external onlyOwner {
        uint256 tokenId = _tokenIdCounter.current();

        // Reward per share
        uint256 _rewardPerShare = _rewardAmount / totalShareCount;

        for (uint32 _i = 1; _i < tokenId; _i++) {

            // Check if the fund exists 
            if (fundExists(_i)) {
                // Calculate the reward
                address _currentHolder = ownerOf(_i);
                uint256 _shareCount = _funds[_i].numberOfShares;
                uint256 _rewardToBeDistributed = _rewardPerShare * _shareCount;

                // Distribute
                IERC20(_rewardToken).safeTransfer(
                    _currentHolder,
                    _rewardToBeDistributed
                );
            }
        }
    }

    function isOwnerOfFunds(address account) public view returns (bool) {
        return balanceOf(account) > 0;
    }

    function isApprovedOrOwnerOfFund(address account, uint256 _fundId)
        public
        view
        returns (bool)
    {
        return _isApprovedOrOwner(account, _fundId);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function burn(uint256 _fundId)
        external
        virtual
        nonReentrant
        onlyFundOwner
        whenNotPaused
        checkPermissions(_fundId)
    {
        _burn(_fundId);
    }

    // The following functions are overrides required by Solidity.

    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        override(ERC721, ERC721Enumerable)
        whenNotPaused
    {
        // TODO Add royalty here 
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

}