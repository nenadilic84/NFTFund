import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import { expect } from 'chai'
import { BigNumber, constants } from 'ethers'
import { ethers, network } from 'hardhat'

import {
  NFTFund,
  NFTFund__factory,
  USDC,
  USDC__factory
} from '../../typechain-types'

describe('NFT Fund', () => {
  let owner: SignerWithAddress,
    feeCollector: SignerWithAddress,
    investor1: SignerWithAddress,
    investor2: SignerWithAddress

  let nftFund: NFTFund
  let USDCToken: USDC
  let ownerBalance: BigNumber

  it('Setup', async () => {
    [owner, feeCollector, investor1, investor2] = await ethers.getSigners()

    nftFund = await new NFTFund__factory(owner).deploy(100)

    USDCToken = await new USDC__factory(owner).deploy('1000000000000')

    await nftFund.editPurchaseToken(USDCToken.address)
    await nftFund.editPurchasePrice(10)
    await nftFund.setDepositToken(USDCToken.address)
    await nftFund.setFeeCollector(feeCollector.address)
    await nftFund.unpause()
  })

  it('Deployment should assign the total supply of tokens to the owner', async () => {

    ownerBalance = await USDCToken.balanceOf(owner.address)

    expect(await USDCToken.totalSupply()).to.equal(ownerBalance)
  })

  it('Transfer USDC to future investors so that they can invest', async () => {
    const balanceDistribution = ownerBalance.div(2)
    expect(await USDCToken.transfer(investor1.address, balanceDistribution))
      .to.emit(USDCToken, 'Transfer')
      .withArgs(owner.address, investor1.address, balanceDistribution)
    
    expect(await USDCToken.balanceOf(investor1.address)).to.eql(
      balanceDistribution
    )
    console.log(
      'balanceOf investor1: ',
      await USDCToken.balanceOf(investor1.address)
    )

    expect(await USDCToken.transfer(investor2.address, balanceDistribution))
      .to.emit(USDCToken, 'Transfer')
      .withArgs(owner.address, investor2.address, balanceDistribution)

    console.log(
      'balanceOf investor2: ',
      await USDCToken.balanceOf(investor2.address)
    )
    
    expect(await USDCToken.balanceOf(investor2.address)).to.eql(
      balanceDistribution
    )

    expect(await USDCToken.balanceOf(owner.address)).to.eql(constants.Zero)
    console.log('USDCToken.address: ', USDCToken.address)
  })

  it('Investors mint NFT', async () => {
    // approve spend
    await USDCToken.connect(investor1).approve(
      nftFund.address,
      ownerBalance
    )
    await USDCToken.connect(investor2).approve(
      nftFund.address,
      ownerBalance
    )
    await USDCToken.connect(owner).approve(
      nftFund.address,
      ownerBalance
    )
 
    const numOfShares = ownerBalance.div(20) // 10 per share divided by 2 among investors from all the balance

    expect(await nftFund.connect(investor1).mintFund(numOfShares, 'First'))
      .to.emit(nftFund, 'FundInvestment')
      .withArgs(investor1.address, constants.One, numOfShares)
    
    expect(await nftFund.connect(investor2).mintFund(numOfShares, 'Second'))
      .to.emit(nftFund, 'FundInvestment')
      .withArgs(investor2.address, constants.Two, numOfShares)

    expect(await nftFund.isOwnerOfFunds(investor1.address)).to.eql(true)
    expect(await nftFund.isOwnerOfFunds(investor2.address)).to.eql(true)
    expect(await nftFund.isOwnerOfFunds(owner.address)).to.eql(false)

    console.log(
      'nftFund.newInvestments: ',
      await nftFund.newInvestments()
    )

    await nftFund.withdrawToOwnerNewInvestments()

    expect(await USDCToken.balanceOf(owner.address)).to.eql(ownerBalance)

  })

})


