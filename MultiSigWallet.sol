// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Simple Multi-Signature Wallet
 * @notice This contract requires multiple owners to confirm transactions before execution.
 * @dev This is a demonstration code and is NOT production-ready or audited.
 */
contract MultiSigWallet {
    // List of owners
    address[] public owners;

    // Mapping to quickly check if an address is an owner
    mapping(address => bool) public isOwner;

    // Number of confirmations required to execute a transaction
    uint256 public required;

    // Struct to store details of each transaction
    struct Transaction {
        address to;
        uint256 value;
        bool executed;
        uint256 confirmations;
    }

    // Array of all transactions
    Transaction[] public transactions;

    // Mapping from txIndex => (owner => bool) to check if an owner has confirmed a transaction
    mapping(uint256 => mapping(address => bool)) public approved;

    /// @dev Emitted when a new transaction is created.
    event SubmitTransaction(uint256 indexed txIndex, address indexed owner, address indexed to, uint256 value);

    /// @dev Emitted when a transaction is confirmed by an owner.
    event ConfirmTransaction(uint256 indexed txIndex, address indexed owner);

    /// @dev Emitted when a transaction is executed successfully.
    event ExecuteTransaction(uint256 indexed txIndex, address indexed owner);

    /**
     * @dev Constructor to set initial owners and the required number of confirmations.
     * @param _owners The list of owner addresses.
     * @param _required The number of required confirmations.
     */
    constructor(address[] memory _owners, uint256 _required) {
        require(_owners.length > 0, "Owners required");
        require(_required > 0 && _required <= _owners.length, "Invalid required number of owners");

        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "Invalid owner");
            require(!isOwner[owner], "Owner not unique");

            isOwner[owner] = true;
            owners.push(owner);
        }
        required = _required;
    }

    /// @dev Allows the contract to receive Ether.
    receive() external payable {}

    /// @dev Fallback function to handle calls without data.
    fallback() external payable {}

    /**
     * @notice Create a new transaction that needs confirmation.
     * @param _to The address to which the transaction will be sent.
     * @param _value The amount of Ether to be sent.
     */
    function submitTransaction(address _to, uint256 _value) external onlyOwner {
        uint256 txIndex = transactions.length;

        transactions.push(Transaction({
            to: _to,
            value: _value,
            executed: false,
            confirmations: 0
        }));

        emit SubmitTransaction(txIndex, msg.sender, _to, _value);
    }

    /**
     * @notice An owner confirms a transaction.
     * @param _txIndex The index of the transaction to confirm.
     */
    function confirmTransaction(uint256 _txIndex) external onlyOwner txExists(_txIndex) notExecuted(_txIndex) {
        require(!approved[_txIndex][msg.sender], "Transaction already confirmed by this owner");

        Transaction storage transaction = transactions[_txIndex];
        transaction.confirmations += 1;
        approved[_txIndex][msg.sender] = true;

        emit ConfirmTransaction(_txIndex, msg.sender);
    }

    /**
     * @notice Execute a transaction if enough owners have confirmed it.
     * @param _txIndex The index of the transaction to execute.
     */
    function executeTransaction(uint256 _txIndex) external onlyOwner txExists(_txIndex) notExecuted(_txIndex) {
        Transaction storage transaction = transactions[_txIndex];
        require(transaction.confirmations >= required, "Not enough confirmations");

        transaction.executed = true;
        (bool success, ) = transaction.to.call{value: transaction.value}("");
        require(success, "Transaction failed");

        emit ExecuteTransaction(_txIndex, msg.sender);
    }

    /// @notice Returns the number of transactions in the wallet.
    function getTransactionCount() external view returns (uint256) {
        return transactions.length;
    }

    /// @notice Returns the balance of Ether held by this contract.
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    modifier onlyOwner() {
        require(isOwner[msg.sender], "Not an owner");
        _;
    }

    modifier txExists(uint256 _txIndex) {
        require(_txIndex < transactions.length, "Transaction does not exist");
        _;
    }

    modifier notExecuted(uint256 _txIndex) {
        require(!transactions[_txIndex].executed, "Transaction already executed");
        _;
    }
}
