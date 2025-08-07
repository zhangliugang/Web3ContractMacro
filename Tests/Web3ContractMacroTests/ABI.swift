import Foundation

public class ABI {
//    public static var erc20ABI = 
//    """
//    [{"constant":true,"inputs":[],"name":"name","outputs":[{"name":"","type":"string"}],"payable":false,"type":"function"}]
//    """
    public static let erc20ABI: StaticString = 
"""
[
    {
        "inputs": [
          {
            "internalType": "uint32",
            "name": "offset",
            "type": "uint32"
          },
          {
            "internalType": "uint32",
            "name": "limit",
            "type": "uint32"
          }
        ],
        "name": "compositeBuckets",
        "outputs": [
          {
            "components": [
              {
                "internalType": "uint64",
                "name": "index",
                "type": "uint64"
              },
              {
                "internalType": "address",
                "name": "candidateAddress",
                "type": "address"
              },
              {
                "internalType": "uint256",
                "name": "stakedAmount",
                "type": "uint256"
              },
              {
                "internalType": "uint32",
                "name": "stakedDuration",
                "type": "uint32"
              },
              {
                "internalType": "int64",
                "name": "createTime",
                "type": "int64"
              },
              {
                "internalType": "int64",
                "name": "stakeStartTime",
                "type": "int64"
              },
              {
                "internalType": "int64",
                "name": "unstakeStartTime",
                "type": "int64"
              },
              {
                "internalType": "bool",
                "name": "autoStake",
                "type": "bool"
              },
              {
                "internalType": "address",
                "name": "owner",
                "type": "address"
              },
              {
                "internalType": "address",
                "name": "contractAddress",
                "type": "address"
              },
              {
                "internalType": "uint64",
                "name": "stakedDurationBlockNumber",
                "type": "uint64"
              },
              {
                "internalType": "uint64",
                "name": "createBlockHeight",
                "type": "uint64"
              },
              {
                "internalType": "uint64",
                "name": "stakeStartBlockHeight",
                "type": "uint64"
              },
              {
                "internalType": "uint64",
                "name": "unstakeStartBlockHeight",
                "type": "uint64"
              }
            ],
            "internalType": "struct IStaking.CompositeVoteBucket[]",
            "name": "",
            "type": "tuple[]"
          }
        ],
        "stateMutability": "view",
        "type": "function"
      }
]
"""
}
