// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title KYCCompliantToken
 * @dev ERC20 token with KYC compliance features for regulatory compliance
 */
contract KYCCompliantToken {
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;
    
    // Token balances mapping
    mapping(address => uint256) private _balances;
    // Allowance mapping for spending approval
    mapping(address => mapping(address => uint256)) private _allowances;
    
    // KYC verification mapping
    mapping(address => bool) private _kycAllowlist;
    
    // Multi-signature admin management
    address[] public adminAddresses;
    uint256 public requiredSignatures;
    uint256 public adminCount;
    
    // Operation ID tracking
    uint256 private _operationId = 0;
    
    // Operation data structure
    struct Operation {
        address target;
        bool isActive;
        uint256 signatureCount;
        mapping(address => bool) signatures;
        bool isKycAddition; // true for addition, false for removal
    }
    
    // Operations mapping
    mapping(uint256 => Operation) private _operations;
    
    // Events
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event KYCStatusChanged(address indexed account, bool status);
    event AdminAdded(address indexed admin);
    event OperationCreated(uint256 indexed operationId, address indexed target, bool isKycAddition);
    event OperationSigned(uint256 indexed operationId, address indexed signer);
    event OperationExecuted(uint256 indexed operationId);
    
    // Error messages
    error SenderNotKYCVerified();
    error RecipientNotKYCVerified();
    error InsufficientBalance();
    error InsufficientAllowance();
    error OnlyAdminCanPerformThisAction();
    error InvalidOperation();
    error AlreadySigned();
    error OperationAlreadyExecuted();
    error NotEnoughSignatures();
    
    /**
     * @dev Constructor sets up the token details and initial admins
     * @param _name Token name
     * @param _symbol Token symbol
     * @param _decimals Token decimal places
     * @param _initialSupply Initial supply of tokens
     * @param _initialAdmins Array of initial admin addresses
     * @param _requiredSignatures Number of required signatures for admin operations
     */
    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        uint256 _initialSupply,
        address[] memory _initialAdmins,
        uint256 _requiredSignatures
    ) {
        require(_initialAdmins.length >= _requiredSignatures, "Invalid admin configuration");
        
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        
        // Mint initial supply to the deployer
        _balances[msg.sender] = _initialSupply;
        totalSupply = _initialSupply;
        
        // Add deployer to KYC allowlist
        _kycAllowlist[msg.sender] = true;
        emit KYCStatusChanged(msg.sender, true);
        
        // Set up multi-signature admin configuration
        for (uint256 i = 0; i < _initialAdmins.length; i++) {
            adminAddresses.push(_initialAdmins[i]);
            emit AdminAdded(_initialAdmins[i]);
        }
        
        adminCount = _initialAdmins.length;
        requiredSignatures = _requiredSignatures;
    }
    
    /**
     * @dev Returns the balance of the given account
     * @param account Address to query balance for
     * @return Balance of the account
     */
    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }
    
    /**
     * @dev Returns the remaining allowance of spender on owner's behalf
     * @param owner Owner of the tokens
     * @param spender Address approved to spend tokens
     * @return Remaining allowance
     */
    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowances[owner][spender];
    }
    
    /**
     * @dev Approves an address to spend tokens on caller's behalf
     * @param spender Address to approve
     * @param amount Amount to approve
     * @return Success indicator
     */
    function approve(address spender, uint256 amount) public returns (bool) {
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }
    
    /**
     * @dev Transfers tokens to the given address
     * @param to Recipient address
     * @param amount Amount to transfer
     * @return Success indicator
     */
    function transfer(address to, uint256 amount) public returns (bool) {
        // Check if sender is KYC verified
        if (!isKYCVerified(msg.sender)) revert SenderNotKYCVerified();
        
        // Check if recipient is KYC verified
        if (!isKYCVerified(to)) revert RecipientNotKYCVerified();
        
        // Check if sender has enough balance
        if (_balances[msg.sender] < amount) revert InsufficientBalance();
        
        // Execute transfer
        _balances[msg.sender] -= amount;
        _balances[to] += amount;
        
        emit Transfer(msg.sender, to, amount);
        return true;
    }
    
    /**
     * @dev Transfers tokens from one address to another using allowance
     * @param from Sender address
     * @param to Recipient address
     * @param amount Amount to transfer
     * @return Success indicator
     */
    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        // Check if sender is KYC verified
        if (!isKYCVerified(from)) revert SenderNotKYCVerified();
        
        // Check if recipient is KYC verified
        if (!isKYCVerified(to)) revert RecipientNotKYCVerified();
        
        // Check if spender has enough allowance
        if (_allowances[from][msg.sender] < amount) revert InsufficientAllowance();
        
        // Check if sender has enough balance
        if (_balances[from] < amount) revert InsufficientBalance();
        
        // Update allowance
        _allowances[from][msg.sender] -= amount;
        
        // Execute transfer
        _balances[from] -= amount;
        _balances[to] += amount;
        
        emit Transfer(from, to, amount);
        return true;
    }
    
    /**
     * @dev Checks if an address is KYC verified
     * @param account Address to check
     * @return Verification status
     */
    function isKYCVerified(address account) public view returns (bool) {
        return _kycAllowlist[account];
    }
    
    /**
     * @dev Checks if an address is an admin
     * @param account Address to check
     * @return Admin status
     */
    function isAdmin(address account) public view returns (bool) {
        for (uint256 i = 0; i < adminCount; i++) {
            if (adminAddresses[i] == account) {
                return true;
            }
        }
        return false;
    }
    
    /**
     * @dev Creates a new KYC addition operation
     * @param account Account to add to KYC allowlist
     * @return Operation ID
     */
    function proposeAddToKYC(address account) public returns (uint256) {
        if (!isAdmin(msg.sender)) revert OnlyAdminCanPerformThisAction();
        
        uint256 id = _operationId++;
        
        Operation storage op = _operations[id];
        op.target = account;
        op.isActive = true;
        op.signatureCount = 0;
        op.isKycAddition = true;
        
        // Auto-sign by the proposer
        op.signatures[msg.sender] = true;
        op.signatureCount = 1;
        
        emit OperationCreated(id, account, true);
        emit OperationSigned(id, msg.sender);
        
        return id;
    }
    
    /**
     * @dev Creates a new KYC removal operation
     * @param account Account to remove from KYC allowlist
     * @return Operation ID
     */
    function proposeRemoveFromKYC(address account) public returns (uint256) {
        if (!isAdmin(msg.sender)) revert OnlyAdminCanPerformThisAction();
        
        uint256 id = _operationId++;
        
        Operation storage op = _operations[id];
        op.target = account;
        op.isActive = true;
        op.signatureCount = 0;
        op.isKycAddition = false;
        
        // Auto-sign by the proposer
        op.signatures[msg.sender] = true;
        op.signatureCount = 1;
        
        emit OperationCreated(id, account, false);
        emit OperationSigned(id, msg.sender);
        
        return id;
    }
    
    /**
     * @dev Signs an existing operation
     * @param operationId ID of the operation to sign
     */
    function signOperation(uint256 operationId) public {
        if (!isAdmin(msg.sender)) revert OnlyAdminCanPerformThisAction();
        
        Operation storage op = _operations[operationId];
        
        if (!op.isActive) revert OperationAlreadyExecuted();
        if (op.signatures[msg.sender]) revert AlreadySigned();
        
        op.signatures[msg.sender] = true;
        op.signatureCount += 1;
        
        emit OperationSigned(operationId, msg.sender);
        
        // Auto-execute if enough signatures are collected
        if (op.signatureCount >= requiredSignatures) {
            _executeOperation(operationId);
        }
    }
    
    /**
     * @dev Executes an operation that has enough signatures
     * @param operationId ID of the operation to execute
     */
    function executeOperation(uint256 operationId) public {
        if (!isAdmin(msg.sender)) revert OnlyAdminCanPerformThisAction();
        
        Operation storage op = _operations[operationId];
        
        if (!op.isActive) revert OperationAlreadyExecuted();
        if (op.signatureCount < requiredSignatures) revert NotEnoughSignatures();
        
        _executeOperation(operationId);
    }
    
    /**
     * @dev Internal function to execute an operation
     * @param operationId ID of the operation to execute
     */
    function _executeOperation(uint256 operationId) internal {
        Operation storage op = _operations[operationId];
        
        op.isActive = false;
        
        if (op.isKycAddition) {
            _kycAllowlist[op.target] = true;
        } else {
            _kycAllowlist[op.target] = false;
        }
        
        emit KYCStatusChanged(op.target, op.isKycAddition);
        emit OperationExecuted(operationId);
    }
    
    /**
     * @dev Gets the current signature count for an operation
     * @param operationId ID of the operation
     * @return Number of signatures collected
     */
    function getOperationSignatureCount(uint256 operationId) public view returns (uint256) {
        return _operations[operationId].signatureCount;
    }
    
    /**
     * @dev Checks if an admin has signed an operation
     * @param operationId ID of the operation
     * @param admin Admin address to check
     * @return Signing status
     */
    function hasAdminSigned(uint256 operationId, address admin) public view returns (bool) {
        return _operations[operationId].signatures[admin];
    }
    
    /**
     * @dev Checks if an operation is active
     * @param operationId ID of the operation
     * @return Activity status
     */
    function isOperationActive(uint256 operationId) public view returns (bool) {
        return _operations[operationId].isActive;
    }
}