# KYC Compliant Token Contract

## Overview
This smart contract implements a KYC (Know Your Customer) compliant ERC20-like token that restricts transfers to verified investors only. The contract integrates an on-chain allowlist mechanism to ensure regulatory compliance for security tokens or other regulated digital assets.

### The Contract was deployed on polygon and address : 0x4ac04Ed71f5EfE5C1bB36246337863B4e404D567

## Features
- **Restricted Transfers**: Only KYC-verified addresses can send or receive tokens
- **Multi-signature Admin Control**: Admin operations require approval from multiple authorized accounts
- **On-chain Allowlist**: Immutable record of KYC verification status
- **Comprehensive Events**: Full event logging for compliance tracking and auditing

## Smart Contract Structure
The contract includes the following key components:
- ERC20-compatible token functionality
- KYC verification status tracking
- Multi-signature administration system
- Operation proposal and approval workflow

## Workflow

### Deployment
1. Deploy the contract with the following parameters:
   - Token name and symbol
   - Decimal places (typically 18)
   - Initial token supply
   - List of admin addresses
   - Required signature threshold

2. Upon deployment:
   - The deployer receives the initial token supply
   - The deployer is automatically KYC-verified
   - The specified admin addresses are registered

### KYC Management

#### Adding a New User to KYC Allowlist
1. An admin calls `proposeAddToKYC(address)` to start the verification process
2. The operation is created and automatically signed by the proposer
3. Other admins review and sign using `signOperation(operationId)`
4. Once the required signature threshold is met, the address is automatically added to the allowlist
5. A `KYCStatusChanged` event is emitted

#### Removing a User from KYC Allowlist
1. An admin calls `proposeRemoveFromKYC(address)` to initiate removal
2. The operation is created and automatically signed by the proposer
3. Other admins review and sign using `signOperation(operationId)`
4. Once the required signature threshold is met, the address is automatically removed from the allowlist
5. A `KYCStatusChanged` event is emitted

### Token Transfers

#### Regular Transfer
1. A user calls `transfer(to, amount)` to send tokens
2. The contract checks if both sender and recipient are KYC-verified
3. If either fails verification, the transaction reverts with a specific error
4. If both are verified, the transfer proceeds normally

#### Delegated Transfer
1. A user first approves a spender using `approve(spender, amount)`
2. The spender calls `transferFrom(from, to, amount)`
3. The contract checks if both the original owner and recipient are KYC-verified
4. If either fails verification, the transaction reverts with a specific error
5. If both are verified, the transfer proceeds normally

## Admin Functions

### Proposing Operations
- `proposeAddToKYC(address)`: Propose adding an address to the KYC allowlist
- `proposeRemoveFromKYC(address)`: Propose removing an address from the KYC allowlist

### Signing Operations
- `signOperation(operationId)`: Sign an existing operation
- `executeOperation(operationId)`: Manually execute an operation with sufficient signatures

### Querying Operations
- `getOperationSignatureCount(operationId)`: Check how many signatures an operation has
- `hasAdminSigned(operationId, admin)`: Check if a specific admin has signed
- `isOperationActive(operationId)`: Check if an operation is still active

## View Functions
- `isKYCVerified(address)`: Check if an address is KYC verified
- `isAdmin(address)`: Check if an address is an admin
- `balanceOf(address)`: Check token balance of an address
- `allowance(owner, spender)`: Check spending allowance

## Error Messages
- `SenderNotKYCVerified`: The sender has not been KYC verified
- `RecipientNotKYCVerified`: The recipient has not been KYC verified
- `InsufficientBalance`: Not enough tokens for the transfer
- `InsufficientAllowance`: Not enough approved tokens for the delegated transfer
- `OnlyAdminCanPerformThisAction`: The caller is not an authorized admin
- `InvalidOperation`: The operation ID does not exist or is malformed
- `AlreadySigned`: The admin has already signed this operation
- `OperationAlreadyExecuted`: The operation has already been completed
- `NotEnoughSignatures`: The operation doesn't have enough signatures to execute

## Events
- `Transfer`: Emitted when tokens are transferred
- `Approval`: Emitted when token spending is approved
- `KYCStatusChanged`: Emitted when an address's KYC status changes
- `AdminAdded`: Emitted when a new admin is added
- `OperationCreated`: Emitted when a new operation is proposed
- `OperationSigned`: Emitted when an operation receives a new signature
- `OperationExecuted`: Emitted when an operation is completed

## Usage Example in Remix

### Deployment
```solidity
// Example deployment parameters
string memory name = "Compliance Token";
string memory symbol = "COMP";
uint8 decimals = 18;
uint256 initialSupply = 1000000 * 10**18; // 1 million tokens
address[] memory initialAdmins = new address[](3);
initialAdmins[0] = 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4; // Admin 1
initialAdmins[1] = 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2; // Admin 2
initialAdmins[2] = 0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db; // Admin 3
uint256 requiredSignatures = 2; // 2-of-3 multisig
```

### Adding a User to KYC Allowlist
1. Admin 1 proposes:
```solidity
// From Admin 1 address
uint256 operationId = proposeAddToKYC(0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB);
```

2. Admin 2 signs:
```solidity
// From Admin 2 address
signOperation(operationId);
// The KYC addition is automatically executed after this signature
```

### Transferring Tokens
```solidity
// From a KYC-verified address to another KYC-verified address
transfer(0x617F2E2fD72FD9D5503197092aC168c91465E7f2, 1000 * 10**18);
```

## Security Considerations
- Once deployed, the list of admins cannot be changed
- The required signature threshold cannot be modified
- Failed transactions clearly indicate the reason for failure
- All operations are transparent and trackable on-chain

## Regulatory Compliance
This contract is designed to assist with regulatory compliance but should be reviewed by legal experts before deployment in a regulated environment.