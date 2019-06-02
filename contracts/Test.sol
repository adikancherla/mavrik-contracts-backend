pragma solidity ^0.5.8;

contract Test {

  uint256 a;

  function set() public {
    a = 10;
  }

  function set2() public {
    a = 11;
  }

  function set3() public {
    a = 12;
  }

  // Reserved storage space to allow for layout changes in the future.
  uint256[50] private ______gap;
}