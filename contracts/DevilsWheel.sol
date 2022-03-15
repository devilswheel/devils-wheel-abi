// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/dev/VRFConsumerBase.sol";

interface DAIPermit {
  function permit(
    address holder,
    address spender,
    uint256 nonce,
    uint256 expiry,
    bool allowed,
    uint8 v,
    bytes32 r,
    bytes32 s
  )
  external;
}

enum BetType {
  Number,
  Color,
  Even,
  Column,
  Dozen,
  Half
}

enum Color {
  Green,
  Red,
  Black
}

contract DevilsWheel is VRFConsumerBase, ERC20, Ownable {
  struct Bet {
    BetType betType;
    uint8 value;
    uint256 amount;
  }
    
  mapping(bytes32 => uint256[3][]) _rollRequestsBets;
  mapping(bytes32 => bool) _rollRequestsCompleted;
  mapping(bytes32 => address) _rollRequestsSender;
  mapping(bytes32 => uint8) _rollRequestsResults;
  mapping(bytes32 => uint256) _rollRequestsTime;
  mapping(uint8 => Color) COLORS;
  
  uint256 BASE_SHARES = uint256(10);

  uint256 public current_liquidity = 0;
  uint256 public locked_liquidity = 0;
  uint256 public collected_fees = 0;
  uint256 public min_bet;
  uint256 public max_bet;
  uint256 public bet_fee;
  uint256 public redeem_min_time = 2 hours;
  uint256 public minLiquidityMultiplier = 50;
  uint8 public constant INVALID_RESULT = 99;

  bytes32 internal keyHash = 0x6e75b569a01ef56d18cab6a8e71e6600d6ce853834d4a5748b720d06f878b3a4;
  uint256 internal fee = 100000000000000;
  address bet_token = 0xbc7948B5d3A9eEd2D04F7f3B443a0bd22B6D9255;
  address vrfCoordinator = 0x8C7382F9D8f56b33781fE506E897a4F1e2d17255;
  address link = 0x326C977E6efc84E512bB9C30f76E30c160eD06FB;

  uint8[18] private RED_NUMBERS = [
    1, 3, 5, 7, 9, 12, 14, 16, 18,
    19, 21, 23, 25, 27, 30, 32, 34, 36
  ];

  event RequestedRandomness(
    bytes32 requestId
  );
  event BetRequest(
    bytes32 requestId,
    address sender
  );
  event BetResult(
    bytes32 requestId,
    uint256 randomResult,
    uint256 payout
  );

  constructor()
    ERC20(
      "DEVILS SHARE",
      "DEVL"
    ) 
    VRFConsumerBase(
      vrfCoordinator,
      link
    )
  {
    max_bet = 10 ** 20;
    bet_fee = 0;
    min_bet = 250000000000000000;

    COLORS[0] = Color.Green;
    
    for (uint8 i = 1; i < 37; i++) {
      COLORS[i] = Color.Black;
    }

    for (uint8 i = 0; i < RED_NUMBERS.length; i++) {
      COLORS[RED_NUMBERS[i]] = Color.Red;
    }
  }

  function removeLiquidity()
    external 
  {
    require(
      balanceOf(msg.sender) > 0,
      "Your don't have liquidity"
    );

    uint256 sender_shares = balanceOf(msg.sender);
    uint256 sender_liquidity =
      (sender_shares * current_liquidity) / totalSupply();

    current_liquidity -= sender_liquidity;
    _burn(
      msg.sender,
      sender_shares
    );
    IERC20(bet_token).transfer(
      msg.sender,
      sender_liquidity
    );
  }

  function redeem(
    bytes32 requestId
  )
    external
  {
    require(
      _rollRequestsCompleted[requestId] == false,
      "requestId already completed"
    );
    require(
      block.timestamp - _rollRequestsTime[requestId] > redeem_min_time,
      "Redeem time not passed"
    );

    _rollRequestsCompleted[requestId] = true;
    _rollRequestsResults[requestId] = INVALID_RESULT;

    uint256 amount = getRollRequestAmount(requestId);

    current_liquidity += amount * 35;
    locked_liquidity -= amount * 36;

    IERC20(bet_token).transfer(
      _rollRequestsSender[requestId],
      amount
    );

    emit BetResult(
      requestId,
      _rollRequestsResults[requestId],
      amount
    );
  }

  function setBetFee(
    uint256 _bet_fee
  )
    external
    onlyOwner
  {
    bet_fee = _bet_fee;
  }

  function setMinBet(
    uint256 _min_bet
  )
    external
    onlyOwner
  {
    min_bet = _min_bet;
  }

  function setMaxBet(
    uint256 _max_bet
  )
    external
    onlyOwner
  {
    max_bet = _max_bet;
  }

  function setMinLiquidityMultiplier(
    uint256 _minLiquidityMultiplier
  )
    external
    onlyOwner
  {
    minLiquidityMultiplier = _minLiquidityMultiplier;
  }

  function withdrawFees()
    external
    onlyOwner
  {
    uint256 _collected_fees = collected_fees;
    collected_fees = 0;

    IERC20(bet_token).transfer(
      owner(),
      _collected_fees
    );
  }

  function setVRFFee(
    uint256 _fee
  )
    external
    onlyOwner
  {
    fee = _fee;
  }

  function addLiquidity(
    uint256 amount,
    uint256 nonce,
    uint expiry,
    bool allowed,
    uint8 v,
    bytes32 r,
    bytes32 s
  )
    public
  {
    collectToken(
      msg.sender,
      amount,
      nonce,
      expiry,
      allowed,
      v,
      r,
      s
    );

    uint256 added_liquidity = amount;
    uint256 current_shares = totalSupply();

    if (current_shares <= 0) {
      current_liquidity += added_liquidity;
      _mint(
        msg.sender,
        BASE_SHARES * ((added_liquidity / 100) * 90)
      );
      _mint(
        owner(),
        BASE_SHARES * ((added_liquidity / 100) * 10)
      );
      return;
    }

    uint256 new_shares =
      (added_liquidity * current_shares) /
      (current_liquidity + locked_liquidity);
    
    current_liquidity += added_liquidity;

    _mint(
      msg.sender,
      ((new_shares / 100) * 90)
    );
    _mint(
      owner(),
      ((new_shares / 100) * 10)
    );
  }

  function addLiquidity(
    uint256 amount
  )
    public
  {
    addLiquidity(
      amount,
      0,
      0,
      false,
      0,
      0,
      0
    );
  }

  function rollBets(
    Bet[] memory bets,
    uint256 randomSeed,
    uint256 nonce,
    uint expiry,
    bool allowed,
    uint8 v,
    bytes32 r,
    bytes32 s
  )
    public
  {
    uint256 amount = 0;

    for (uint index = 0; index < bets.length; index++) {
      require(bets[index].value < 37);
      amount += bets[index].amount;
    }

    require(
      amount <= getMaxBet(),
      "Your bet exceeds the max allowed"
    );

    require(
      amount >= min_bet,
      "Your bet is below table minimum"
    );

    collectToken(
      msg.sender,
      amount + bet_fee,
      nonce,
      expiry,
      allowed,
      v,
      r,
      s
    );
    
    current_liquidity -= amount * 35;
    locked_liquidity += amount * 36;
    collected_fees += bet_fee;

    bytes32 requestId = getRandomNumber(randomSeed);

    emit BetRequest(
      requestId,
      msg.sender
    );
        
    _rollRequestsSender[requestId] = msg.sender;
    _rollRequestsCompleted[requestId] = false;
    _rollRequestsTime[requestId] = block.timestamp;

    for (uint i; i < bets.length; i++) {
      _rollRequestsBets[requestId].push([
        uint256(bets[i].betType),
        uint256(bets[i].value),
        uint256(bets[i].amount)
      ]);
    }
  }

  function rollBets(
    Bet[] memory bets,
    uint256 randomSeed
  )
    public
  {
    rollBets(
      bets,
      randomSeed,
      0,
      0,
      false,
      0,
      0,
      0
    );
  }

  function isRequestCompleted(
    bytes32 requestId
  )
    public
    view
    returns(bool)
  {
    return _rollRequestsCompleted[requestId];
  }

  function requesterOf(
    bytes32 requestId
  )
    public
    view
    returns(address)
  {
    return _rollRequestsSender[requestId];
  }

  function resultOf(
    bytes32 requestId
  )
    public
    view
    returns(uint8)
  {
    return _rollRequestsResults[requestId];
  }

  function betsOf(
    bytes32 requestId
  )
    public
    view
    returns(uint256[3][] memory)
  {
    return _rollRequestsBets[requestId];
  }

  function getCurrentLiquidity()
    public
    view
    returns(uint256)
  {
    return current_liquidity;
  }

  function getBetFee()
    public
    view
    returns(uint256)
  {
    return bet_fee;
  }

  function getMinBet()
    public
    view
    returns(uint256)
  {
    return min_bet;
  }

  function getMaxBet()
    public
    view
    returns(uint256)
  {
    uint256 maxBetForLiquidity =
      current_liquidity / minLiquidityMultiplier;

    if (max_bet > maxBetForLiquidity) {
      return maxBetForLiquidity;
    }

    return max_bet;
  }

  function getCollectedFees()
    public
    view
    returns(uint256)
  {
    return collected_fees;
  }

  function fulfillRandomness(
    bytes32 requestId,
    uint256 randomness
  )
    internal
    override
  {
    require(
      _rollRequestsCompleted[requestId] == false
    );

    uint8 result = uint8(randomness % 37);
    uint256[3][] memory bets = _rollRequestsBets[requestId];
    uint256 rollLockedAmount =
      getRollRequestAmount(requestId) * 36;

    current_liquidity += rollLockedAmount;
    locked_liquidity -= rollLockedAmount;

    uint256 amount = 0;

    for (uint index = 0; index < bets.length; index++) {
      BetType betType = BetType(bets[index][0]);
      uint8 betValue = uint8(bets[index][1]);
      uint256 betAmount = bets[index][2];

      if (
        betType == BetType.Number &&
        result == betValue
      )
      {
        amount += betAmount * 36;
        continue;
      }

      if (
        result == 0 &&
        betType == BetType.Color
      )
      {
        amount += betAmount / 2;
        continue;
      }

      if (
        result == 0 &&
        betType == BetType.Even
      )
      {
        amount += betAmount / 2;
        continue;
      }

      if (
        result == 0 &&
        betType == BetType.Half
      )
      {
        amount += betAmount / 2;
        continue;
      }

      if (
        betType == BetType.Color &&
        uint8(COLORS[result]) == betValue
      ) 
      {
        amount += betAmount * 2;
        continue;
      }

      if (
        betType == BetType.Even &&
        result % 2 == betValue
      ) 
      {
        amount += betAmount * 2;
        continue;
      }

      if (
        betType == BetType.Column &&
        result % 3 == betValue
      )
      {
        amount += betAmount * 3;
        continue;
      }

      if (
        betType == BetType.Dozen &&
        betValue * 12 < result &&
        result <= (betValue + 1) * 12)
      {
        amount += betAmount * 3;
        continue;
      }

      if (
        betType == BetType.Half &&
        (betValue != 0 ? (result >= 19) : (result < 19))
      )
      {
        amount += betAmount * 2;
        continue;
      }
    }

    _rollRequestsResults[requestId] = result;
    _rollRequestsCompleted[requestId] = true;

    if (amount > 0) {
      IERC20(bet_token).transfer(
        _rollRequestsSender[requestId],
        amount
      );
      current_liquidity -= amount;
    }

    emit BetResult(requestId, result, amount);
  }

  function getRollRequestAmount(
    bytes32 requestId
  )
    internal
    view
    returns(uint256)
  {
    uint256[3][] memory bets = _rollRequestsBets[requestId];
    uint256 amount = 0;

    for (uint index = 0; index < bets.length; index++) {
      uint256 betAmount = bets[index][2];
      amount += betAmount;
    }

    return amount;
  }

  function getRandomNumber(
    uint256 userProvidedSeed
  ) 
    private
    returns (bytes32 requestId) 
  {
    require(
      LINK.balanceOf(address(this)) >= fee,
      "Not enough LINK - fill contract with faucet"
    );

    bytes32 _requestId = requestRandomness(
      keyHash,
      fee,
      userProvidedSeed
    );

    emit RequestedRandomness(_requestId);

    return _requestId;
  }

  function collectToken(
    address sender,
    uint256 amount,
    uint256 nonce,
    uint expiry,
    bool allowed,
    uint8 v,
    bytes32 r,
    bytes32 s
  )
    private
  {
    if (expiry != 0) {
      DAIPermit(bet_token).permit(
        sender,
        address(this),
        nonce,
        expiry,
        allowed,
        v,
        r,
        s
      );
    }

    IERC20(bet_token).transferFrom(
      sender,
      address(this),
      amount
    );
  }    
}
