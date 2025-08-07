# A simple contract marco for https://github.com/web3swift-team/web3swift
** just for study, do not use it in your project. **

## Usage
```
@Web3Contract("""
    [{"constant":true,"inputs":[{"name":"_owner","type":"address"}],"name":"balanceOf","outputs":[{"name":"balance","type":"uint256"}],"payable":false,"type":"function"}]
""")
class Contract {
}
```
This code will expand as:
```
class Contract {
    private let abiString = """
            [{"constant":true,"inputs":[{"name":"_owner","type":"address"}],"name":"balanceOf","outputs":[{"name":"balance","type":"uint256"}],"payable":false,"type":"function"}]
    """

    private let contract: EthereumContract
    private let contractAddress: EthereumAddress
    private var web3: Web3

    init(address: EthereumAddress, web3: Web3) {
        self.contractAddress = address
        self.web3 = web3
        self.contract = try! EthereumContract(abiString)
    }

    func balanceOf(_owner: EthereumAddress) async throws -> BigUInt {
        let method = contract.methods["balanceOf(address)"]!.first!
        let data = method.encodeParameters([_owner])
        let transaction = CodableTransaction(to: contractAddress, data: data!)
        let returnData = try await web3.eth.callTransaction(transaction)
        let result = try method.decodeReturnData(returnData)
        return result["0"] as! BigUInt
    }
}
```
