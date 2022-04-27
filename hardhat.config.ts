import '@nomiclabs/hardhat-etherscan'
import '@nomiclabs/hardhat-waffle'
import '@typechain/hardhat'
import 'hardhat-gas-reporter'
import 'solidity-coverage'

import * as dotenv from 'dotenv'
import { HardhatUserConfig } from 'hardhat/config'

dotenv.config()

const rinkebyURL = process.env.RINKEBY_URL ?? ''
const accounts = process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : undefined

const config: HardhatUserConfig = {
  solidity: {
    version: '0.8.12',
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  networks: {
    hardhat: {
      chainId: 1337
    },
    rinkeby: {
      url: rinkebyURL,
      accounts
    }
  },
  gasReporter: {
    enabled: true,
    currency: 'USD'
  }
}

export default config
