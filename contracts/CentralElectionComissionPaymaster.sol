// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./eth-infinitism-aa/interfaces/IPaymaster.sol";
import "./eth-infinitism-aa/interfaces/IEntryPoint.sol";


import "./CentralElectionComissionAA.sol";
import "hardhat/console.sol";

contract CentralElectionComissionPaymaster is Initializable, IPaymaster {

    CentralElectionComissionAA public centralElectionComissionAA;

    mapping(address => uint256) public senderNonce;

    modifier onlyCentralElectionCommisionAA() {
        require(msg.sender == address(centralElectionComissionAA));
        _;
    }

    function initialize(
        CentralElectionComissionAA _centralElectionComissionAA
    ) public initializer {
        centralElectionComissionAA = _centralElectionComissionAA;
    }

    /// @inheritdoc IPaymaster
    function validatePaymasterUserOp(
        UserOperation calldata userOp, 
        bytes32 userOpHash, 
        uint256 maxCost
    ) external override returns (bytes memory context, uint256 validationData) {
        _requireFromEntryPoint();
        return _validatePaymasterUserOp(userOp, userOpHash, maxCost);
    }

    function _validatePaymasterUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash, 
        uint256 maxCost
    ) internal returns (bytes memory context, uint256 validationData) {
        senderNonce[userOp.sender]++;
        //userOp.paymasterAndData;
       
        return ("", _packValidationData(false, 0, 0));
    }

    /// @inheritdoc IPaymaster
    function postOp(
        PostOpMode mode, 
        bytes calldata context, 
        uint256 actualGasCost
    ) external override {
        _requireFromEntryPoint();
        _postOp(mode, context, actualGasCost);
    }

    /**
     * post-operation handler.
     * (verified to be called only through the entryPoint)
     * @dev if subclass returns a non-empty context from validatePaymasterUserOp, it must also implement this method.
     * @param mode enum with the following options:
     *      opSucceeded - user operation succeeded.
     *      opReverted  - user op reverted. still has to pay for gas.
     *      postOpReverted - user op succeeded, but caused postOp (in mode=opSucceeded) to revert.
     *                       Now this is the 2nd call, after user's op was deliberately reverted.
     * @param context - the context value returned by validatePaymasterUserOp
     * @param actualGasCost - actual gas used so far (without this postOp call).
     */
    function _postOp(PostOpMode mode, bytes calldata context, uint256 actualGasCost) internal {

        (mode,context,actualGasCost); // unused params
        // subclass must override this method if validatePaymasterUserOp returns a context
        revert("must override");
    }

    /**
     * add a deposit for this paymaster, used for paying for transaction fees
     */
    function deposit() public payable {
        centralElectionComissionAA.entryPoint().depositTo{value : msg.value}(address(this));
    }

    /**
     * withdraw value from the deposit
     * @param withdrawAddress target to send to
     * @param amount to withdraw
     */
    function withdrawTo(address payable withdrawAddress, uint256 amount) public onlyCentralElectionCommisionAA {
       centralElectionComissionAA.entryPoint().withdrawTo(withdrawAddress, amount);
    }

    /**
     * add stake for this paymaster.
     * This method can also carry eth value to add to the current stake.
     * @param unstakeDelaySec - the unstake delay for this paymaster. Can only be increased.
     */
    function addStake(uint32 unstakeDelaySec) external payable onlyCentralElectionCommisionAA {
        centralElectionComissionAA.entryPoint().addStake{value : msg.value}(unstakeDelaySec);
    }

    /**
     * return current paymaster's deposit on the entryPoint.
     */
    function getDeposit() public view returns (uint256) {
        return centralElectionComissionAA.entryPoint().balanceOf(address(this));
    }

    /**
     * unlock the stake, in order to withdraw it.
     * The paymaster can't serve requests once unlocked, until it calls addStake again
     */
    function unlockStake() external onlyCentralElectionCommisionAA {
        centralElectionComissionAA.entryPoint().unlockStake();
    }

    /**
     * withdraw the entire paymaster's stake.
     * stake must be unlocked first (and then wait for the unstakeDelay to be over)
     * @param withdrawAddress the address to send withdrawn value.
     */
    function withdrawStake(address payable withdrawAddress) external onlyCentralElectionCommisionAA {
        centralElectionComissionAA.entryPoint().withdrawStake(withdrawAddress);
    }

    /// validate the call is made from a valid entrypoint
    function _requireFromEntryPoint() internal view {
        require(msg.sender == address(centralElectionComissionAA.entryPoint()), "CentralElectionComissionPaymaster: Sender not EntryPoint");
    }

}
