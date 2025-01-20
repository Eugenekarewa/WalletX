import { useState, useEffect } from 'react';
import { WalletX_backend } from 'declarations/WalletX_backend';
import { AuthClient } from '@dfinity/auth-client';
import { QRCodeCanvas } from 'qrcode.react';

function App() {
  const [account, setAccount] = useState('');
  const [amountKES, setAmountKES] = useState(0);
  const [transferFrom, setTransferFrom] = useState('');
  const [transferTo, setTransferTo] = useState('');
  const [transferAmount, setTransferAmount] = useState(0);
  const [balance, setBalance] = useState(0);
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [qrCodeValue, setQRCodeValue] = useState('');
  const [walletAddress, setWalletAddress] = useState('');
  const [error, setError] = useState('');
  const [userPrincipal, setUserPrincipal] = useState('');

  useEffect(() => {
    fetchBalance();
    if (userPrincipal) {
      fetchWalletAddress(userPrincipal);
    }
  }, [userPrincipal]);

  const fetchBalance = async () => {
    try {
      const currentBalance = await WalletX_backend.wallet_balance();
      setBalance(currentBalance);
    } catch (err) {
      setError('Failed to fetch balance. Please try again later.');
    }
  };

  const fetchWalletAddress = async (principal) => {
    try {
      console.log("Fetching wallet address for principal:", principal); // Log the principal
      const address = await WalletX_backend.getDepositAddress(principal);
      setWalletAddress(address);
      setQRCodeValue(address);
    } catch (err) {
      console.error("Error fetching wallet address:", err); // Log any errors
      setError('Failed to fetch wallet address. Please try again later.');
    }
  };

  const handleDeposit = async (event) => {
    event.preventDefault();
    try {
      await WalletX_backend.depositKES(account, amountKES);
      fetchBalance();
    } catch (err) {
      setError('Deposit failed. Please check your input and try again.');
    }
  };

  const handleTransfer = async (event) => {
    event.preventDefault();
    try {
      await WalletX_backend.transfer_tokens(transferFrom, transferTo, transferAmount);
      fetchBalance();
    } catch (err) {
      setError('Transfer failed. Please check your input and try again.');
    }
  };

  const handleLogin = async () => {
    console.log("Attempting to log in..."); // Log the login attempt
    const authClient = await AuthClient.create();
    authClient.login({
      identityProvider: 'https://identity.ic0.app',
      onSuccess: async () => {
        const principal = await authClient.getIdentity();
        console.log("Login successful. User Principal:", principal); // Log the successful login
        setUserPrincipal(principal);
        setIsAuthenticated(true);
        fetchWalletAddress(principal); // Fetch wallet address after login
      },
      onError: (err) => {
        setError('Login failed. Please try again.');
      },
    });
  };

  return (
    <main>
      <h2>Wallet Operations</h2>
      <h3>Current Balance: {balance} Tokens</h3>
      {error && <p style={{ color: 'red' }}>{error}</p>}

      <h4>Your Wallet Address: {walletAddress}</h4>
      {qrCodeValue && <QRCodeCanvas value={qrCodeValue} />}

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
