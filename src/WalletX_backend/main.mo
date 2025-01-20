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

    // State variables for balances and transactions
    private stable var balanceEntries: [(Text, Nat)] = [];
    private var balances = HashMap.fromIter<Text, Nat>(balanceEntries.vals(), 100, Text.equal, Text.hash);

    private stable var transactionEntries: [(Text, [(Text, Nat)])] = [];
    private var transactions = HashMap.fromIter<Text, [(Text, Nat)]>(transactionEntries.vals(), 100, Text.equal, Text.hash);

    // Exchange rate: 1 KES = 1 Token (modifiable)
    private stable var exchangeRate: Nat = 1;

    // Logging function with verbosity levels
    private func log(level: Text, message: Text) {
        Debug.print("[" # level # "] " # message);
    };

    // Function to check the current cycle balance of the canister
    public query func wallet_balance(): async Nat {
    let cycleBalance = Cycles.balance();
    Debug.print("Current canister cycle balance: " # Nat.toText(cycleBalance));
    return cycleBalance;
};

    // Function to accept cycles sent to the wallet
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

    // Function to update the exchange rate
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

    // Function to check an account's token balance
    public query func check_balance(account: Text): async Nat {
    Option.get(balances.get(account), 0)
    };

    // Function to fetch transaction history for an account
    public query func getTransactionHistory(account: Text): async ?[(Text, Nat)] {
    transactions.get(account)
    };

    // Function to deposit Kenyan Shillings (KES) into the wallet
    public func depositKES(account: Text, amountKES: Nat): async Bool {
        // Convert KES to Tokens based on the exchange rate
        let tokenAmount = amountKES * exchangeRate;

        // Check for overflow
        let currentBalance = Option.get(balances.get(account), 0);
        if (currentBalance + tokenAmount < currentBalance) {
            log("ERROR", "Overflow detected while depositing tokens.");
            return false;
        };

        let newBalance = currentBalance + tokenAmount;
        balances.put(account, newBalance);

        // Record the deposit transaction
        let transaction = (Int.toText(Time.now()), tokenAmount);
        let accountTransactions = Option.get(transactions.get(account), []);
        transactions.put(account, Array.append(accountTransactions, [transaction]));

        log("INFO", "Deposited " # Nat.toText(amountKES) # " KES as " # Nat.toText(tokenAmount) # " tokens to account: " # account);
        return true;
    };

    // Function to transfer tokens to another account
    public func transfer_tokens(from: Text, to: Text, amount: Nat): async Bool {
        let fromBalance = Option.get(balances.get(from), 0);
        if (fromBalance < amount) {
            log("ERROR", "Insufficient balance for transfer.");
            return false;
        };

        // Deduct from sender's balance
        balances.put(from, fromBalance - amount);

        // Add to receiver's balance
        let toBalance = Option.get(balances.get(to), 0);
        balances.put(to, toBalance + amount);

        // Record the transaction
        let transaction = (Int.toText(Time.now()), amount);
        let senderTransactions = Option.get(transactions.get(from), []);
        transactions.put(from, Array.append(senderTransactions, [transaction]));
        let receiverTransactions = Option.get(transactions.get(to), []);
        transactions.put(to, Array.append(receiverTransactions, [transaction]));

        log("INFO", "Transferred " # Nat.toText(amount) # " tokens from " # from # " to " # to);
        return true;
    };

    // Function to transfer cycles to another canister
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
