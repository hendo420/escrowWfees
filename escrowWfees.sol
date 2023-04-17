pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Escrow {

    IERC20 public usdt;
    address public owner;
    uint256 public feePercentage = 1;
    
    enum EscrowStatus {EMPTY, FILLED, COMPLETED, REFUNDED}
    
    struct EscrowStruct {
        uint256 amount;
        address buyer;
        address seller;
        EscrowStatus status;
    }
    
    mapping(uint256 => EscrowStruct) public escrows;
    uint256 public nextEscrowId;
    
    uint256 public feesCollected;
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract Escrow is ReentrancyGuard {
    IERC20 public usdt;
    address public owner;
    uint256 public feePercentage = 1;

    enum EscrowStatus {EMPTY, FILLED, COMPLETED, REFUNDED, REJECTED}
    struct EscrowStruct {
        uint256 amount;
        address buyer;
        address seller;
        EscrowStatus status;
    }

    mapping(uint256 => EscrowStruct) public escrows;
    uint256 public nextEscrowId;

    uint256 public feesCollected;

    event EscrowCreated(uint256 escrowId, uint256 amount, address buyer, address seller);
    event EscrowFilled(uint256 escrowId);
    event EscrowReleased(uint256 escrowId);
    event EscrowRefunded(uint256 escrowId);
    event EscrowRejected(uint256 escrowId);
    event FeesWithdrawn(uint256 amount);
    event FeePercentageUpdated(uint256 newFeePercentage);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    constructor(address _usdt) {
        require(_usdt != address(0), "USDT address must not be the zero address");
        usdt = IERC20(_usdt);
        owner = msg.sender;
    }

    function createEscrow(uint256 _amount, address _seller) external {
        require(_amount > 0, "Amount must be greater than 0");
        require(_seller != address(0), "Seller must not be the zero address");

        uint256 escrowId = nextEscrowId++;
        EscrowStruct memory newEscrow = EscrowStruct({
            amount: _amount,
            buyer: msg.sender,
            seller: _seller,
            status: EscrowStatus.EMPTY
        });

        escrows[escrowId] = newEscrow;
        emit EscrowCreated(escrowId, _amount, msg.sender, _seller);
    }

    function fillEscrow(uint256 _escrowId) external nonReentrant {
        EscrowStruct storage escrow = escrows[_escrowId];
        require(escrow.status == EscrowStatus.EMPTY, "Escrow must be empty");
        require(msg.sender == escrow.buyer, "Only the buyer can fill the escrow");

        uint256 fees = (escrow.amount * feePercentage) / 100;
        uint256 totalAmount = escrow.amount + fees;
        usdt.transferFrom(msg.sender, address(this), totalAmount);

        escrow.status = EscrowStatus.FILLED;
        feesCollected += fees;
        emit EscrowFilled(_escrowId);
    }

    function releaseEscrow(uint256 _escrowId) external nonReentrant {
        EscrowStruct storage escrow = escrows[_escrowId];
        require(escrow.status == EscrowStatus.FILLED, "Escrow must be filled");
        require(msg.sender == escrow.seller || msg.sender == owner, "Only the seller or contract owner can release the     escrow");
        usdt.transfer(escrow.seller, escrow.amount);
        escrow.status = EscrowStatus.COMPLETED;
        emit EscrowReleased(_escrowId);
    }


    function refundEscrow(uint256 _escrowId) external onlyOwner nonReentrant {
        EscrowStruct storage escrow = escrows[_escrowId];
        require(escrow.status == EscrowStatus.FILLED, "Escrow must be filled");

        uint256 fees = (escrow.amount * feePercentage) / 100;
        uint256 totalAmount = escrow.amount + fees;
        usdt.transfer(escrow.buyer, totalAmount);
        escrow.status = EscrowStatus.REFUNDED;
        feesCollected -= fees;
        emit EscrowRefunded(_escrowId);
    }

function rejectEscrow(uint256 _escrowId) external nonReentrant {
    EscrowStruct storage escrow = escrows[_escrowId];
    require(escrow.status == EscrowStatus.EMPTY, "Escrow must be empty");
    require(msg.sender == escrow.seller, "Only the seller can reject the escrow");

    escrow.status = EscrowStatus.REJECTED;
    emit EscrowRejected(_escrowId);
}

function withdrawFees() external onlyOwner nonReentrant {
    require(feesCollected > 0, "No fees to withdraw");
    uint256 amount = feesCollected;
    feesCollected = 0;
    usdt.transfer(owner, amount);
    emit FeesWithdrawn(amount);
}

function setFeePercentage(uint256 _newFeePercentage) external onlyOwner {
    require(_newFeePercentage <= 100, "Fee percentage must be between 0 and 100");
    feePercentage = _newFeePercentage;
    emit FeePercentageUpdated(_newFeePercentage);
}

function getEscrowStatus(uint256 _escrowId) external view returns (EscrowStatus) {
    return escrows[_escrowId].status;
}


