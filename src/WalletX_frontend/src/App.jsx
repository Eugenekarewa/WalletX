import { useState, useEffect } from 'react';
import { WalletX_backend } from 'declarations/WalletX_backend';
import { AuthClient } from '@dfinity/auth-client';

function App() {
  const [account, setAccount] = useState('');
  const [amountKES, setAmountKES] = useState(0);
  const [transferFrom, setTransferFrom] = useState('');
  const [transferTo, setTransferTo] = useState('');
  const [transferAmount, setTransferAmount] = useState(0);
  const [balance, setBalance] = useState(0);
  const [isAuthenticated, setIsAuthenticated] = useState(false);

  useEffect(() => {
    // Fetch the current balance when the component mounts
    fetchBalance();
  }, []);

  const fetchBalance = async () => {
    const currentBalance = await WalletX_backend.wallet_balance();
    setBalance(currentBalance);
  };

  const handleDeposit = async (event) => {
    event.preventDefault();
    await WalletX_backend.depositKES(account, amountKES);
    fetchBalance(); // Refresh balance after deposit
  };

  const handleTransfer = async (event) => {
    event.preventDefault();
    await WalletX_backend.transfer_tokens(transferFrom, transferTo, transferAmount);
    fetchBalance(); // Refresh balance after transfer
  };

  const handleLogin = async () => {
    const authClient = await AuthClient.create();
    authClient.login({
      identityProvider: 'https://identity.ic0.app', // Internet Identity provider
      onSuccess: async () => {
        setIsAuthenticated(true);
        // Fetch user account information or perform any necessary actions
        const account = await authClient.getIdentity();
      },
      onError: (err) => {
        console.error('Login failed:', err);
      },
    });
  };

  return (
    <main>
      <h2>Wallet Operations</h2>
      <h3>Current Balance: {balance} Tokens</h3>

      {!isAuthenticated ? (
        <button onClick={handleLogin}>Login with Internet Identity</button>
      ) : (
        <>
          <form onSubmit={handleDeposit}>
            <h4>Deposit KES</h4>
            <input
              type="text"
              placeholder="Account"
              value={account}
              onChange={(e) => setAccount(e.target.value)}
            />
            <input
              type="number"
              placeholder="Amount in KES"
              value={amountKES}
              onChange={(e) => setAmountKES(Number(e.target.value))}
            />
            <button type="submit">Deposit</button>
          </form>

          <form onSubmit={handleTransfer}>
            <h4>Transfer Tokens</h4>
            <input
              type="text"
              placeholder="From Account"
              value={transferFrom}
              onChange={(e) => setTransferFrom(e.target.value)}
            />
            <input
              type="text"
              placeholder="To Account"
              value={transferTo}
              onChange={(e) => setTransferTo(e.target.value)}
            />
            <input
              type="number"
              placeholder="Amount"
              value={transferAmount}
              onChange={(e) => setTransferAmount(Number(e.target.value))}
            />
            <button type="submit">Transfer</button>
          </form>
        </>
      )}
    </main>
  );
}

export default App;
