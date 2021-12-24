// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

contract MultiSigWallet {

    
    event TxSubmitted(
        address indexed owner,
        uint indexed txIndex,
        address indexed to,
        uint value,
        bytes data
    );
    event TxConfirmed(address indexed owner, uint indexed txIndex);
    event TxRevoked(address indexed owner, uint indexed txIndex);
    event TxExecuted(address indexed owner, uint indexed txIndex);
    event Deposited(address indexed sender, uint amount, uint balance);

    address[] public owners;
    mapping(address => bool) public isOwner;
    uint public numOfConfirmationsRequired;

    struct Transaction {
        address to;
        uint value;
        bytes data;
        bool executed;
        uint numOfConfirmations;
    }

    // tx to owner to confirmed or not
    mapping(uint => mapping(address => bool)) public isConfirmed;

    Transaction[] public transactions;

    modifier onlyOwner() {
        require(isOwner[msg.sender], "not owner");
        _;
    }

    modifier txExists(uint _txIndex) {
        require(_txIndex < transactions.length, "transaction doesn't exist");
        _;
    }

    modifier notExecuted(uint _txIndex) {
        require(!transactions[_txIndex].executed, "transaction already executed");
        _;
    }

    modifier notConfirmed(uint _txIndex) {
        require(!isConfirmed[_txIndex][msg.sender], "transaction already confirmed");
        _;
    }

    constructor(address[] memory _owners, uint _numOfConfirmationsRequired) {
        require(_owners.length > 0, "add atleast one owner");
        require(
            _numOfConfirmationsRequired > 0 &&
                _numOfConfirmationsRequired <= _owners.length,
            "invalid number of required confirmations"
        );

        for (uint i = 0; i < _owners.length; i++) {
            address owner = _owners[i];

            require(owner != address(0), "invalid owner");
            require(!isOwner[owner], "owner not unique");

            isOwner[owner] = true;
            owners.push(owner);
        }

        numOfConfirmationsRequired = _numOfConfirmationsRequired;
    }

    receive() external payable {
        emit Deposited(msg.sender, msg.value, address(this).balance);
    }

    function addMoreOwner(address adr) public onlyOwner {
        require(owner != address(0), "invalid owner");
        require(!isOwner[owner], "owner not unique");
        isOwner[adr] = true;
        owners.push(adr);
    } 

    function submitTransaction(
        address _to,
        uint _value,
        bytes memory _data
    ) public onlyOwner {
        uint txIndex = transactions.length;

        transactions.push(
            Transaction({
                to: _to,
                value: _value,
                data: _data,
                executed: false,
                numOfConfirmations: 0
            })
        );

        emit TxSubmitted(msg.sender, txIndex, _to, _value, _data);
    }

    function confirmTransaction(uint _txIndex)
        public
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
        notConfirmed(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];
        transaction.numOfConfirmations += 1;
        isConfirmed[_txIndex][msg.sender] = true;

        emit TxConfirmed(msg.sender, _txIndex);
    }

    function executeTransaction(uint _txIndex)
        public
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];

        require(
            transaction.numOfConfirmations >= numOfConfirmationsRequired,
            "Need more confirmations to execute"
        );

        transaction.executed = true;

        (bool success, ) = transaction.to.call{value: transaction.value}(
            transaction.data
        );
        require(success, "transaction failed");

        emit TxExecuted(msg.sender, _txIndex);
    }

    function revokeConfirmation(uint _txIndex)
        public
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];

        require(isConfirmed[_txIndex][msg.sender], "Can't cancel a transaction that you haven't confirmed");

        transaction.numOfConfirmations -= 1;
        isConfirmed[_txIndex][msg.sender] = false;

        emit TxRevoked(msg.sender, _txIndex);
    }

    function getOwners() public view returns (address[] memory) {
        return owners;
    }

    function getTransactionCount() public view returns (uint) {
        return transactions.length;
    }

    function getTransaction(uint _txIndex)
        public
        view
        returns (
            address to,
            uint value,
            bytes memory data,
            bool executed,
            uint numOfConfirmations
        )
    {
        Transaction storage transaction = transactions[_txIndex];

        return (
            transaction.to,
            transaction.value,
            transaction.data,
            transaction.executed,
            transaction.numOfConfirmations
        );
    }
}
