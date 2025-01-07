# Lottery - A Blockchain-Based Raffle System

## Overview

Lottery is a decentralized raffle system built on Ethereum, leveraging Chainlink's VRF (Verifiable Random Function) and subscription features to ensure a secure, unbiased, and automated winner selection process. The project is written in Solidity and utilizes the Foundry framework for development and testing.

---

## Features

- **Secure and Transparent Raffle**: Uses Chainlink VRF v2.5 to generate verifiable random numbers for selecting winners.
- **Automated Processes**: Employs Chainlink Keepers for upkeep checks, ensuring smooth and autonomous operation.
- **Subscription Management**: Utilizes Chainlink's subscription feature to manage funding for VRF requests.
- **User-Friendly**: Participants can enter the raffle with a simple transaction, and winners are automatically picked based on randomness.

---

## Contract Details

### **Raffle.sol**

- **Key Functionalities**:
  - **enterRaffle()**: Allows users to enter the raffle by paying the entrance fee.
  - **checkUpkeep()**: Checks if conditions are met for upkeep (e.g., enough time has passed, raffle is open, etc.).
  - **performUpkeep()**: Initiates the winner selection process by requesting a random number.
  - **fulfillRandomWords()**: Chainlink callback function to determine the winner based on the random number.

- **State Variables**:
  - `i_entranceFee`: The fee required to enter the raffle.
  - `i_interval`: Duration of the raffle in seconds.
  - `s_lastTimeStamp`: Tracks the last upkeep timestamp.
  - `s_players`: List of participants in the raffle.
  - `s_recentWinner`: Address of the most recent raffle winner.
  - `s_raffleState`: Current state of the raffle (OPEN or CALCULATING).

- **Events**:
  - `RaffleEnter`: Emitted when a user enters the raffle.
  - `WinnerPicked`: Emitted when a winner is selected.
  - `RequestedRaffleWinner`: Emitted when a random number is requested.

---

## Dependencies

- **Solidity v0.8.19**
- **Chainlink VRF v2.5**
- **Foundry for Development and Testing**: Includes `forge-std` library for debugging and testing.

---

## Getting Started

### Prerequisites

- Foundry installed: [Foundry Documentation](https://book.getfoundry.sh/).

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/mudit004/Lottery
   cd Lottery
   ```

2. Install dependencies:
   ```bash
   forge install
   ```

3. Set up environment variables:
   Create a `.env` file and add the following variables:
   ```plaintext
   PRIVATE_KEY=<Your Private Key>
   SEPOLIA_RPC_URL=<Your Sepolia RPC URL>
   ETHERSCAN_API_KEY=<Your ETHERSCAN_API_KEY>
   SUBSCRIPTION_ID=<Your chainlink subscription id>
   ```
4. Update the values according to your subscription in `HelperConfig.s.sol` file

---

## Running Tests

1. Run the test suite:
   ```bash
   forge test
   ```

2. View detailed logs:
   ```bash
   forge test -vv
   ```

---

## Deployment

1. Configure deployment parameters in the script located in `script/`.
2. Deploy the contract using Foundry:
   ```bash
   forge script script/DeployRaffle.s.sol --rpc-url <network-rpc-url> --private-key <private-key> --broadcast
   ```

---

## Usage

1. **Enter the Raffle**:
   Call the `enterRaffle()` function with the required entrance fee.

2. **Automated Upkeep**:
   Chainlink Keepers will monitor the contract and perform upkeep when conditions are met.

3. **Winner Selection**:
   The winner is selected automatically using Chainlink VRF, and funds are transferred to the winner's address.
