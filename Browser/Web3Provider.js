(function(window) {

 class TesseractProvider {
    constructor(net) {
        this._callbacks = {};
        this._state = { network: net, account: null };
        this.isMetaMask = true;
    }

    isConnected() {
        return true;
    }
 
    processRequest(request, callback) {
        const id = request.id;
     
        this._callbacks[id] = (error, result) => {
            delete this._callbacks[id];
 
            if (error) {
                var reply = {id, jsonrpc: request.jsonrpc, error: error};
                alert(JSON.stringify(reply));
                callback(reply, null);
            } else {
                var reply = {id, jsonrpc: request.jsonrpc, result: result};
                callback(null, reply);
            }
        }
 
        const jsonRequest = JSON.stringify(request);
        window.webkit.messageHandlers.tes.postMessage(jsonRequest);
    }
 
    processBatch(requests, callback) {
        const batchSize = requests.length;
        var context = { isResponded: false, responses: [] };
        requests.forEach(request => {
            this.processRequest(request, (error, result) => {
                if (context.isResponded) return;
                if (error) {
                    callback(error, null);
                    context.isResponded = true;
                } else {
                    context.responses.push(result)
                    if (context.responses.length === batchSize) {
                        context.isResponded = true
                        callback(null, context.responses)
                    }
                }
            });
        });
    }
 
    sendAsync(data, callback) {
        if (Array.isArray(data)) {
            this.processBatch(data, callback);
        } else {
            this.processRequest(data, callback);
        }
    }
 
    send(request, callback) {
        if (callback) {
            this.sendAsync(request, callback);
            return;
        }

        var response = null
        alert("SYNC REQUEST: " + JSON.stringify(request));
        switch (request.method) {
        case "net_version":
            response = this._state.network.toString();
            break;
        case "eth_accounts":
            response = this._state.account ? [this._state.account] : []
            break;
        case "eth_coinbase":
            response = this._state.account ? this._state.account : null;
            break;
        case "eth_uninstallFilter":
            this.sendAsync(request, () => {})
            response = true
            break
        default:
            throw new Error("Sync call " + request.method + " is not supported.");
        }

        return { id: request.id, jsonrpc: request.jsonrpc, result: response };
    }

    setState(key, value) {
        const k = JSON.parse(key);
        const v = JSON.parse(value);
        this._state[k] = v;
        if (k === "account") {
            window.web3.eth.defaultAccount = v;
        }
    }
 
    accept(id, error, result) {
        const callback = this._callbacks[id];
 
        if(callback) {
            const err = JSON.parse(error);
            const res = JSON.parse(result);
 
            callback(err, res);
        } else {
            alert("WTF??? Callback for id is not there: " + id);
        }
    }
 }
 
 class TesWeb3 {
    constructor(net) {
        this._net = net;
        this.version = {
            network: net.toString(),
            node: null,
            api: "0.20.3",
            ethereum: null,
            whisper: null
        };
    }

    get currentProvider() {
        if(this._currentProvider === undefined) {
            this._currentProvider = new TesseractProvider(this._net);
        }
 
        return this._currentProvider;
    }
 }
 
 window.web3 = new TesWeb3(window.__ethereum_network_version);
})(window);

