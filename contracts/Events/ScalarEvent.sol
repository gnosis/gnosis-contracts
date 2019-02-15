pragma solidity ^0.4.24;
import "../Events/Event.sol";
import "@gnosis.pm/util-contracts/contracts/Proxy.sol";


contract ScalarEventData {

    /*
     *  Constants
     */
    uint8 public constant SHORT = 0;
    uint8 public constant LONG = 1;
    uint24 public constant OUTCOME_RANGE = 1000000;

    /*
     *  Storage
     */
    int public lowerBound;
    int public upperBound;
}

contract ScalarEventProxy is Proxy, EventData, ScalarEventData {

    /// @dev Contract constructor validates and sets basic event properties
    /// @param _collateralToken Tokens used as collateral in exchange for outcome tokens
    /// @param _oracle Oracle contract used to resolve the event
    /// @param _lowerBound Lower bound for event outcome
    /// @param _upperBound Lower bound for event outcome
    constructor(
        address proxied,
        address outcomeTokenMasterCopy,
        ERC20Gnosis _collateralToken,
        Oracle _oracle,
        int _lowerBound,
        int _upperBound
    )
        Proxy(proxied)
        public
    {
        // Validate input
        require(address(_collateralToken) != 0 && address(_oracle) != 0);
        collateralToken = _collateralToken;
        oracle = _oracle;
        // Create an outcome token for each outcome
        for (uint8 i = 0; i < 2; i++) {
            OutcomeToken outcomeToken = OutcomeToken(new OutcomeTokenProxy(outcomeTokenMasterCopy));
            outcomeTokens.push(outcomeToken);
            emit OutcomeTokenCreation(outcomeToken, i);
        }

        // Validate bounds
        require(_upperBound > _lowerBound);
        lowerBound = _lowerBound;
        upperBound = _upperBound;
    }
}

/// @title Scalar event contract - Scalar events resolve to a number within a range
/// @author Stefan George - <stefan@gnosis.pm>
contract ScalarEvent is Proxied, Event, ScalarEventData {
    using SafeMath for *;

    function redeemWinnings()
        public
        returns (uint winnings)
    {
      // Winning outcome has to be set
      require(isOutcomeSet);

      uint shortOutcomeTokenCount = outcomeTokens[SHORT].balanceOf(msg.sender);
      uint longOutcomeTokenCount = outcomeTokens[LONG].balanceOf(msg.sender);

      outcomeTokens[SHORT].revoke(msg.sender, shortOutcomeTokenCount);
      outcomeTokens[LONG].revoke(msg.sender, longOutcomeTokenCount);

      winnings = calculateWinnings(msg.sender, shortOutcomeTokenCount,longOutcomeTokenCount);

      // Revoke all outcome tokens
      // Payout winnings to sender
      require(collateralToken.transfer(msg.sender, winnings));
      emit WinningsRedemption(msg.sender, winnings);
    }

    /*
     *  Public functions
     */
    /// @dev Exchanges sender's winning outcome tokens for collateral tokens
    /// @return Sender's winnings
    function calculateWinnings(address recipient, uint shortOutcomeTokenCount, uint longOutcomeTokenCount)
        public
        returns (uint winnings)
    {
        // Calculate winnings
        uint24 convertedWinningOutcome;
        // Outcome is lower than defined lower bound
        if (outcome < lowerBound)
            convertedWinningOutcome = 0;
        // Outcome is higher than defined upper bound
        else if (outcome > upperBound)
            convertedWinningOutcome = OUTCOME_RANGE;
        // Map outcome to outcome range
        else
            convertedWinningOutcome = uint24(OUTCOME_RANGE * (outcome - lowerBound) / (upperBound - lowerBound));
        uint factorShort = OUTCOME_RANGE - convertedWinningOutcome;
        uint factorLong = OUTCOME_RANGE - factorShort;

        winnings = shortOutcomeTokenCount.mul(factorShort).add(longOutcomeTokenCount.mul(factorLong)) / OUTCOME_RANGE;
    }

    /// @dev Calculates and returns event hash
    /// @return Event hash
    function getEventHash()
        public
        view
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(collateralToken, oracle, lowerBound, upperBound));
    }
}
