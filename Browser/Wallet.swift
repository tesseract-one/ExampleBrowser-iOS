//
//  Wallet.swift
//  Browser
//
//  Created by Yehor Popovych on 3/17/19.
//  Copyright © 2019 Tesseract Systems, Inc. All rights reserved.
//

import Foundation
import Tesseract
import Serializable

extension NSError: SerializableValueEncodable {
    
    public var serializable: SerializableValue {
        return SerializableValue([
            "code": code,
            "domain": domain,
            "debug": debugDescription,
            "description": description
        ])
    }
}

extension SerializableError {
    static func error(_ err: Swift.Error) -> SerializableError {
        return .object([
            "code": (-32000).serializable,
            "message": "\(err)".serializable,
            "data": [(err as NSError).serializable].serializable
        ])
    }
    
    static func web3Error(code: Int, message: String) -> SerializableError {
        return .object([
            "code": code.serializable,
            "message": message.serializable
        ])
    }
}

class Wallet {
    typealias AccountRequest = (id: Int, method: String, cb: (Int, Swift.Result<SerializableValueEncodable, SerializableError>) -> Void)
    private let endpoint:String
    
    private let web3: Web3
    private weak var webState: TesWebStateSink?
    
    private static var encoder = JSONEncoder()
    private static var decoder = JSONDecoder()
    
    private var account: Address? = nil {
        didSet {
            if let account = account {
                webState?.setState(key: "account", value: account.hex(eip55: false))
            } else {
                webState?.setState(key: "account", value: nil)
            }
        }
    }
    
    private var pendingAccountsRequests: Array<AccountRequest> = []
    
    init(web3: Web3, endpoint: String, webState: TesWebStateSink) {
        self.web3 = web3
        self.endpoint = endpoint
        self.webState = webState
        request(id: 0, method: "eth_accounts", message: Data()) { _, _ in }
        //        let req = """
        
        //{"jsonrpc":"2.0","method":"eth_signTypedData","params":["0x0de8e243816f0fa76f1ab947d87bf2bfdbc18baf", {"types":{"EIP712Domain":[{"name":"name","type":"string"},{"name":"version","type":"string"},{"name":"chainId","type":"uint256"},{"name":"verifyingContract","type":"address"}],"Person":[{"name":"name","type":"string"},{"name":"wallet","type":"address"}, {"name":"child","type":"Person"}],"Mail":[{"name":"from","type":"Person"},{"name":"to","type":"Person"},{"name":"contents","type":"string"}]},"primaryType":"Mail","domain":{"name":"Ether Mail","version":"1","chainId":1,"verifyingContract":"0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC"},"message":{"from":{"name":"Cow","wallet":"0xCD2a3d9F938E13CD947Ec05AbC7FE734Df8DD826", "child":{"name":"Cow Child","wallet":"0x222a3d9F938E13CD947Ec05AbC7FE734Df8DD826", "child":{"name":"Cow Child Child","wallet":"0x332a3d9F938E13CD947Ec05AbC7FE734Df8DD826", "child":null}}},"to":{"name":"Bob","wallet":"0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB", "child":null},"contents":"Hello, Bob!"}}],"id":1}
        
        //"""
        
        //        request(id: 1, method: "eth_signTypedData", message: req.data(using: .utf8)!) { _, _, _ in }
    }
    
    //rewrite to processors
    func request(
        id: Int, method:String, message: Data, callback: @escaping (Int, Swift.Result<SerializableValueEncodable, SerializableError>) -> Void
    ) {
        print("REQ", String(data: message, encoding: .utf8) ?? "UNKNOWN")
        switch method {
        case "eth_accounts":
            fallthrough
        case "eth_coinbase":
            if let account = self.account {
                if method == "eth_coinbase" {
                    callback(id, .success(account.hex(eip55: false)))
                } else {
                    callback(id, .success([account.hex(eip55: false)]))
                }
            } else {
                pendingAccountsRequests.append((id: id, method: method, cb: callback))
                if pendingAccountsRequests.count == 1 {
                    web3.eth.accounts() { res in
                        switch res {
                        case .success(let accounts):
                            self.account = accounts.first
                            self._respondToAccounts(response: .success(accounts))
                        case .failure(let err): self._respondToAccounts(response: .failure(.error(err)))
                        }
                    }
                }
            }
        case "eth_signTypedData": fallthrough
        case "eth_signTypedData_v3": fallthrough
        case "personal_signTypedData": fallthrough
        case "personal_signTypedData_v3":
            let params = try! Wallet.decoder.decode(RPCRequest<SignTypedDataCallParams>.self, from: message).params
            web3.eth.signTypedData(account: params.account, data: params.data) { res in
                callback(id, res.map { $0.hex }.mapError { .error($0) })
            }
        case "personal_sign":
            let params = try! Wallet.decoder.decode(RPCRequest<[Ethereum.Value]>.self, from: message).params
            let account = try! Address(ethereumValue: params[1])
            web3.personal.sign(message: params[0].data!, account: account, password: "") { res in
                callback(id, res.map { $0.hex }.mapError { .error($0) })
            }
        case "eth_sign":
            let params = try! Wallet.decoder.decode(RPCRequest<[Ethereum.Value]>.self, from: message).params
            let account = try! Address(ethereumValue: params[0])
            web3.eth.sign(account: account, message: params[1].data!) { res in
                callback(id, res.map { $0.hex }.mapError { .error($0) })
            }
        case "eth_sendTransaction":
            let tx = try! Wallet.decoder.decode(RPCRequest<[Transaction]>.self, from: message).params[0]
            web3.eth.sendTransaction(transaction: tx) { res in
                callback(id, res.map { $0.hex }.mapError { .error($0) })
            }
        case "eth_newFilter":
            let params = try! Wallet.decoder.decode(RPCRequest<[NewFilterParams]>.self, from: message).params[0]
            web3.eth.newFilter(fromBlock: params.fromBlock, toBlock: params.toBlock, address: params.address, topics: params.topics) { res in
                callback(id, res.map { $0.hex }.mapError { .error($0) })
            }
        case "eth_newPendingTransactionFilter":
            web3.eth.newPendingTransactionFilter() { res in
                callback(id, res.map { $0.hex }.mapError { .error($0) })
            }
        case "eth_newBlockFilter":
            web3.eth.newBlockFilter() { res in
                callback(id, res.map { $0.hex }.mapError { .error($0) })
            }
        case "eth_getFilterLogs":
            let quantity = try! Wallet.decoder.decode(RPCRequest<[Ethereum.Value]>.self, from: message).params[0]
            web3.eth.getFilterLogs(id: quantity.quantity!) { res in
                callback(id, res.map { self._asJsonObject(obj: $0) }.mapError { .error($0) })
            }
            
        case "eth_getFilterChanges":
            let quantity = try! Wallet.decoder.decode(RPCRequest<[Ethereum.Value]>.self, from: message).params[0]
            web3.eth.getFilterChanges(id: quantity.quantity!) { res in
                callback(id, res.map { self._asJsonObject(obj: $0) }.mapError { .error($0) })
            }
        case "eth_uninstallFilter":
            let quantity = try! Wallet.decoder.decode(RPCRequest<[Ethereum.Value]>.self, from: message).params[0]
            web3.eth.uninstallFilter(id: quantity.quantity!) { res in
                callback(id, res.map{ $0 }.mapError { .error($0) })
            }
        case "eth_call":
            var params = try! Wallet.decoder.decode(RPCRequest<CallParams>.self, from: message).params
            if params.from == nil, let account = self.account {
                let call = Call(
                    from: account, to: params.to, gas: params.gas,
                    gasPrice: params.gasPrice, value: params.value, data: params.data
                )
                params = CallParams(call: call, block: params.block)
            }
            web3.eth.call(call: params.call, block: params.block) { res in
                callback(id, res.map { $0.hex }.mapError { .error($0) })
            }
        default:
            var req = try! Wallet.decoder.decode(SerializableValue.self, from: message).object!
            req["id"] = web3.rpcId.serializable
            web3.provider.dataProvider.send(data: SerializableValue(req).jsonData) { result in
                callback(id, result
                    .map { res in
                        let js = try! Wallet.decoder.decode(SerializableValue.self, from: res)
                        return js.object!["result"]
                    }
                    .mapError { .error($0) }
                )
            }
        }
    }
    
    private func _respondToAccounts(response: Swift.Result<[Address], SerializableError>) {
        switch response {
        case .failure(let err):
            for req in pendingAccountsRequests {
                req.cb(req.id, .failure(err))
            }
        case .success(let accs):
            let accounts = accs.map{$0.hex(eip55: false)}
            for req in pendingAccountsRequests {
                if req.method == "eth_coinbase" {
                    req.cb(req.id, .success(accounts.first))
                } else {
                    req.cb(req.id, .success(accounts))
                }
            }
        }
        pendingAccountsRequests.removeAll()
    }
    
    private func _asJsonObject<E: Encodable>(obj: E) -> SerializableValue {
        let data = try! Wallet.encoder.encode(obj)
        return try! Wallet.decoder.decode(SerializableValue.self, from: data)
    }
}


extension Wallet {
    func process(sink:TesWebSink, webMessage:TesWebMessage) -> Void {
        switch webMessage {
        case .message(id: let id, method: let method, message: let message):
            request(id: id, method: method, message: message) { id, result in
                sink.reply(id: id, result: result)
            }
        case .unknown(name: let name, data: let data):
            print("Unknown message: ", name, " with payload: ", data)
        }
    }
    
    func link(web: TesWebView) {
        web.addMessage(recepient: process)
    }
}
