import Principal "mo:base/Principal";
import HashMap "mo:base/HashMap";
import Debug "mo:base/Debug";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Result "mo:base/Result";
import Cycles "mo:base/ExperimentalCycles";
import Option "mo:base/Option";
import Int "mo:base/Int";
import Array "mo:base/Array";
import ExperimentalCycles "mo:base/ExperimentalCycles";
import Error "mo:base/Error";
import Iter "mo:base/Iter";
import Trie "mo:base/Trie";
import Nat8 "mo:base/Nat8";
import Blob "mo:base/Blob";

actor WalletX {
    type TransferArgs = {
        from_subaccount: ?Blob;
        to: {
            owner: Principal;
            subaccount: ?Blob;
        };
        amount: Nat;
        fee: ?Nat;
        memo: ?Blob;
        created_at_time: ?Time.Time;
    };

    type Account = {
        owner: Principal;
        subaccount: ?Blob;
    };

    private stable var balanceEntries: [(Text, Nat)] = [];
    private var balances = HashMap.fromIter<Text, Nat>(balanceEntries.vals(), 100, Text.equal, Text.hash);
    private var tokenBalances : Trie.Trie<TokenId, TokenBalance> = Trie.empty();

    private stable var transactionEntries: [(Text, [(Text, Nat)])] = [];
    private var transactions = HashMap.fromIter<Text, [(Text, Nat)]>(transactionEntries.vals(), 100, Text.equal, Text.hash);

    private stable var exchangeRate: Nat = 1;

    private func log(level: Text, message: Text) {
        Debug.print("[" # level # "] " # message);
    };

    type TokenId= Text;
    type TokenBalance = Nat;

    public query func dump() : async [(TokenId, TokenBalance)] {
        Iter.toArray(Trie.iter(tokenBalances))
    };

    public query func wallet_balance(): async Nat {
        let cycleBalance = Cycles.balance();
        Debug.print("Current canister cycle balance: " # Nat.toText(cycleBalance));
        return cycleBalance;
    };

    public func wallet_receive(): async Bool {
        let available = Cycles.available();
        if (available > 0) {
            let accepted = Cycles.accept(available);
            Debug.print("Accepted cycles: " # Nat.toText(accepted));
            return true;
        } else {
            Debug.print("No cycles received.");
            return false;
        }
    };

    public func updateExchangeRate(newRate: Nat): async Bool {
        if (newRate > 0) {
            exchangeRate := newRate;
            log("INFO", "Exchange rate updated to: " # Nat.toText(newRate));
            return true;
        } else {
            log("ERROR", "Invalid exchange rate.");
            return false;
        }
    };

    public query func check_balance(account: Text): async Nat {
        Option.get(balances.get(account), 0)
    };

    public query func getTransactionHistory(account: Text): async ?[(Text, Nat)] {
        transactions.get(account)
    };

    public func depositKES(user : Principal, _account: Text, amountKES: Nat): async Bool {
        let account = Principal.toText(user);
        let tokenAmount = amountKES * exchangeRate;
        let currentBalance = Option.get(balances.get(account), 0);
        if (currentBalance + tokenAmount < currentBalance) {
            log("ERROR", "Overflow detected while depositing tokens.");
            return false;
        };

        let newBalance = currentBalance + tokenAmount;
        balances.put(account, newBalance);
        let transaction = (Int.toText(Time.now()), tokenAmount);
        let accountTransactions = Option.get(transactions.get(account), []);
        transactions.put(account, Array.append(accountTransactions, [transaction]));

        log("INFO", "Deposited " # Nat.toText(amountKES) # " KES as " # Nat.toText(tokenAmount) # " tokens to account: " # account);
        return true;
    };

    public func getDepositAddress(principal: Principal): async Text {
        let principalBlob = Principal.toBlob(principal);
        let principalBytes = Blob.toArray(principalBlob);
        let paddedBytes = Array.tabulate<Nat8>(32, func (i) {
            if (i < principalBytes.size()) { principalBytes[i] } else { 0 }
        });
        bytesToHex(paddedBytes)
    };
    private func bytesToHex(bytes: [Nat8]): Text {
        let hexChars = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "a", "b", "c", "d", "e", "f"];
        var result = "0x";
        for (byte in bytes.vals()) {
            result #= hexChars[Nat8.toNat(byte / 16)] # hexChars[Nat8.toNat(byte % 16)];
        };
        result
    };

    public func transfer_tokens(from: Text, to: Text, amount: Nat): async Bool {
        let fromBalance = Option.get(balances.get(from), 0);
        if (fromBalance < amount) {
            log("ERROR", "Insufficient balance for transfer.");
            return false;
        };

        balances.put(from, fromBalance - amount);
        let toBalance = Option.get(balances.get(to), 0);
        balances.put(to, toBalance + amount);
        let transaction = (Int.toText(Time.now()), amount);
        let senderTransactions = Option.get(transactions.get(from), []);
        transactions.put(from, Array.append(senderTransactions, [transaction]));
        let receiverTransactions = Option.get(transactions.get(to), []);
        transactions.put(to, Array.append(receiverTransactions, [transaction]));

        log("INFO", "Transferred " # Nat.toText(amount) # " tokens from " # from # " to " # to);
        return true;
    };

    public func transfer_cycles(toCanister: Principal, amount: Nat): async Result.Result<(), Text> {
        let cycleBalance = ExperimentalCycles.balance();
        if (amount > cycleBalance) {
            log("ERROR", "Insufficient cycles for transfer.");
            return #err("Insufficient cycles for transfer.");
        };

        let accepted = ExperimentalCycles.accept(amount);
        try {
            let wallet_receive = actor(Principal.toText(toCanister)) : actor { wallet_receive : () -> async { accepted : Nat64 } };
            let result = await wallet_receive.wallet_receive();
            log("INFO", "Successfully transferred " # Nat.toText(amount) # " cycles to canister: " # Principal.toText(toCanister));
            #ok()
        } catch (error : Error) {
            Debug.print("Failed to transfer cycles: " # Error.message(error));
            #err("Reject message: " # Error.message(error))
        }
    };
};
