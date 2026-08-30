// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import {Initializable as InitializableUpgradeable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "./IProcedureExecutionContext.sol";

/// @notice ERC-20 representation of equity settled by an approved procedure.
contract EquityToken is
    InitializableUpgradeable,
    ERC20Upgradeable,
    ERC20VotesUpgradeable
{
    bytes32 public constant TRANSFER_PROCEDURE_ROLE = keccak256("TRANSFER_PROCEDURE_ROLE");
    bytes32 public constant ADMIN_PROCEDURE_ROLE = keccak256("ADMIN_PROCEDURE_ROLE");

    mapping(bytes32 => mapping(address => bool)) private procedures;
    mapping(bytes32 => uint256) private procedureCounts;

    event ProcedureAuthorizationUpdated(
        bytes32 indexed role,
        address indexed procedure,
        bool authorized
    );

    modifier onlyAuthorizedProcedure(bytes32 role) {
        require(procedures[role][msg.sender], "Not authorized procedure.");
        (bool isApplying,,) = IProcedureExecutionContext(msg.sender).getExecutionContext();
        require(isApplying, "Procedure is not applying a proposal.");
        _;
    }

    function initialize(
        string memory name_,
        string memory symbol_,
        address initialHolder_,
        uint256 initialSupply_,
        address transferProcedure_
    ) external initializer {
        require(initialHolder_ != address(0), "Initial holder required.");
        require(transferProcedure_ != address(0), "Transfer procedure required.");

        __ERC20_init(name_, symbol_);
        __EIP712_init(name_, "1");
        __ERC20Votes_init();

        _setProcedureAuthorization(
            TRANSFER_PROCEDURE_ROLE,
            transferProcedure_,
            true
        );
        _setProcedureAuthorization(
            ADMIN_PROCEDURE_ROLE,
            transferProcedure_,
            true
        );
        _mint(initialHolder_, initialSupply_);
    }

    function decimals() public pure override returns (uint8) {
        return 0;
    }

    /// @notice Settles a transfer initiated by an authorized procedure.
    /// @dev The calling procedure writes the matching movement record immediately afterwards.
    function settleTransfer(
        address recipient,
        uint256 amount
    ) external onlyAuthorizedProcedure(TRANSFER_PROCEDURE_ROLE) {
        (bool isApplying,, address seller) = IProcedureExecutionContext(msg.sender).getExecutionContext();
        require(isApplying, "Transfer must be applied by a proposal.");
        require(
            IProcedureExecutionContext(msg.sender)
                .isSettlingEquityTransfer(),
            "Transfer must include a movement record."
        );
        _validateTransfer(seller, recipient, amount, "movement");

        _transfer(seller, recipient, amount);
    }

    /// @notice Grant or revoke a transfer or administration procedure through governance.
    function setProcedureAuthorization(
        bytes32 role,
        address procedure,
        bool authorized
    ) external onlyAuthorizedProcedure(ADMIN_PROCEDURE_ROLE) {
        require(
            role == TRANSFER_PROCEDURE_ROLE || role == ADMIN_PROCEDURE_ROLE,
            "Unknown procedure role."
        );
        require(procedure != address(0), "Procedure required.");

        if (!authorized && procedures[role][procedure]) {
            require(procedureCounts[role] > 1, "At least one procedure required.");
        }
        _setProcedureAuthorization(role, procedure, authorized);
    }

    /// @notice Checks the transfer conditions during proposal creation.
    function validateTransfer(
        address creator,
        address recipient,
        uint256 amount,
        string calldata movementCid
    ) external view {
        _validateTransfer(creator, recipient, amount, movementCid);
    }

    function isProcedureAuthorized(
        bytes32 role,
        address procedure
    ) external view returns (bool) {
        return procedures[role][procedure];
    }

    function isTransferProcedure(address procedure) external view returns (bool) {
        return procedures[TRANSFER_PROCEDURE_ROLE][procedure];
    }

    function _setProcedureAuthorization(
        bytes32 role,
        address procedure,
        bool authorized
    ) private {
        bool wasAuthorized = procedures[role][procedure];
        if (wasAuthorized == authorized) return;

        procedures[role][procedure] = authorized;
        if (authorized) {
            procedureCounts[role] += 1;
        } else {
            procedureCounts[role] -= 1;
        }
        emit ProcedureAuthorizationUpdated(role, procedure, authorized);
    }

    function _validateTransfer(
        address seller,
        address recipient,
        uint256 amount,
        string memory movementCid
    ) private view {
        require(seller != address(0), "Seller required.");
        require(recipient != address(0) && recipient != seller, "Valid recipient required.");
        require(amount != 0, "Amount required.");
        require(bytes(movementCid).length != 0, "Movement record required.");
        require(balanceOf(seller) >= amount, "Insufficient equity units.");
    }

    function _update(address from, address to, uint256 value)
        internal
        override(ERC20Upgradeable, ERC20VotesUpgradeable)
    {
        if (from != address(0) && to != address(0)) {
            require(
                procedures[TRANSFER_PROCEDURE_ROLE][msg.sender],
                "Transfers must be settled by an authorized procedure."
            );
            require(
                IProcedureExecutionContext(msg.sender)
                    .isSettlingEquityTransfer(),
                "Transfer must include a movement record."
            );
        }
        super._update(from, to, value);
        // Shares confer voting rights to their holder by default. A holder may
        // still delegate those rights to a representative afterwards.
        if (to != address(0) && delegates(to) == address(0)) {
            _delegate(to, to);
        }
    }

    constructor() {
        _disableInitializers();
    }
}
