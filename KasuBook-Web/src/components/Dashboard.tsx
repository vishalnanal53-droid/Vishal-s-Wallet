import { useState, useEffect } from 'react';
import { Transaction, UserSettings } from '../types';
import TransactionForm from './TransactionForm';
import TransactionHistory from './TransactionHistory';
import Settings from './Settings';
import { Wallet, History, Settings as SettingsIcon, LogOut, Smartphone } from 'lucide-react';
import { db } from '../lib/firebase';
import { collection, query, orderBy, onSnapshot, doc, setDoc } from 'firebase/firestore';
import { useAuth } from '../contexts/AuthContext';

type View = 'dashboard' | 'history' | 'settings';

export default function Dashboard() {
  const { user, logout } = useAuth();
  const [view, setView] = useState<View>('dashboard');
  const [transactions, setTransactions] = useState<Transaction[]>([]);
  const [settings, setSettings] = useState<UserSettings | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    document.title = 'KasuBook';
    const link = document.querySelector("link[rel~='icon']") as HTMLLinkElement;
    if (link) {
      link.href = '/kasubook_icon.svg';
    }

    if (!user) return;
    setLoading(true);

    // Listen to settings
    const unsubscribeSettings = onSnapshot(doc(db, 'users', user.uid), (docSnap) => {
      if (docSnap.exists()) {
        setSettings(docSnap.data() as UserSettings);
      } else {
        // Create default settings if not exists
        const defaultSettings = {
          id: user.uid,
          username: user.email?.split('@')[0] || 'User',
          initial_amount: 0,
          initial_cash: 0,
          initial_upi: 0,
          custom_tags: [],
          created_at: new Date().toISOString(),
          updated_at: new Date().toISOString()
        };
        setDoc(doc(db, 'users', user.uid), defaultSettings);
        setSettings(defaultSettings);
      }
    });

    // Listen to transactions
    const q = query(collection(db, 'users', user.uid, 'transactions'), orderBy('transaction_date', 'desc'));
    const unsubscribeTransactions = onSnapshot(q, (snapshot) => {
      const txs = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() })) as Transaction[];
      // Sort by date and time descending (Newest to Oldest)
      txs.sort((a: any, b: any) => {
        const timeA = a.transaction_time || '00:00';
        const timeB = b.transaction_time || '00:00';
        const dateA = new Date(`${a.transaction_date}T${timeA}`);
        const dateB = new Date(`${b.transaction_date}T${timeB}`);
        return dateB.getTime() - dateA.getTime();
      });
      setTransactions(txs);
      setLoading(false);
    });

    return () => {
      unsubscribeSettings();
      unsubscribeTransactions();
    };
  }, [user]);

  const calculateBalance = () => {
    const totalIncome = transactions
      .filter(t => t.type === 'income')
      .reduce((sum, t) => sum + Number(t.amount), 0);

    const totalExpense = transactions
      .filter(t => t.type === 'expense')
      .reduce((sum, t) => sum + Number(t.amount), 0);

    return Number(settings?.initial_amount || 0) + totalIncome - totalExpense;
  };

  const calculateBreakdown = () => {
    const upi = transactions
      .filter(t => t.payment_method === 'UPI')
      .reduce((sum, t) => sum + (t.type === 'income' ? Number(t.amount) : -Number(t.amount)), 0);

    const cash = transactions
      .filter(t => t.payment_method === 'Cash')
      .reduce((sum, t) => sum + (t.type === 'income' ? Number(t.amount) : -Number(t.amount)), 0);

    return { 
      upi: upi + ((settings as any)?.initial_upi || 0), 
      cash: cash + ((settings as any)?.initial_cash || 0) 
    };
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-indigo-500 via-purple-500 to-pink-500 flex items-center justify-center">
        <div className="text-white text-xl">Loading...</div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50">
      <header className="bg-gradient-to-r from-indigo-600 via-purple-600 to-pink-500 text-white shadow-lg">
        <div className="max-w-7xl mx-auto px-4 py-6">
          <div className="flex items-center justify-between">
            <div className="flex items-center space-x-4">
              {/* SVG Icon Container */}
              <div className="bg-white/20 p-2 rounded-2xl backdrop-blur-md border border-white/30">
                {/* Unngaludaiya kasubook_icon.svg code-ai inge paste pannavum */}
                <img 
                  src="/kasubook_icon.svg" 
                  alt="Logo" 
                  className="w-10 h-10" 
                />
              </div>

              <div>
                <h1 className="text-2xl font-black tracking-tight">
                  Kasu<span className="text-indigo-100">Book</span>
                </h1>
                <p className="text-xs font-medium text-white/80 uppercase tracking-wider">
                  Hello, {settings?.username || 'User'}!
                </p>
              </div>
            </div>
            <button
              onClick={() => logout()}
              className="flex items-center space-x-2 bg-white/10 hover:bg-white/20 border border-white/20 px-4 py-2 rounded-xl transition-all duration-200 backdrop-blur-sm group"
            >
              <LogOut className="w-4 h-4 group-hover:-translate-x-1 transition-transform" />
              <span className="font-medium text-sm">Logout</span>
            </button>
          </div>

          <div className="mt-6 bg-white/20 backdrop-blur-sm rounded-xl p-4">
            <p className="text-sm text-white/80 mb-1">Current Balance</p>
            <p className="text-3xl font-bold mb-4">₹{calculateBalance().toFixed(2)}</p>
            
            <div className="grid grid-cols-2 gap-4 pt-4 border-t border-white/20">
              <div>
                <p className="text-xs text-white/80 mb-1">UPI Amount</p>
                <p className="text-lg font-semibold">₹{calculateBreakdown().upi.toFixed(2)}</p>
              </div>
              <div>
                <p className="text-xs text-white/80 mb-1">Cash Amount</p>
                <p className="text-lg font-semibold">₹{calculateBreakdown().cash.toFixed(2)}</p>
              </div>
            </div>
          </div>
        </div>
      </header>

      <nav className="bg-white shadow-sm sticky top-0 z-10">
        <div className="max-w-7xl mx-auto px-4">
          <div className="flex space-x-1">
            <button
              onClick={() => setView('dashboard')}
              className={`flex items-center space-x-2 px-6 py-4 font-medium transition ${
                view === 'dashboard'
                  ? 'text-indigo-600 border-b-2 border-indigo-600'
                  : 'text-gray-600 hover:text-gray-900'
              }`}
            >
              <Wallet className="w-4 h-4" />
              <span>Dashboard</span>
            </button>
            <button
              onClick={() => setView('history')}
              className={`flex items-center space-x-2 px-6 py-4 font-medium transition ${
                view === 'history'
                  ? 'text-indigo-600 border-b-2 border-indigo-600'
                  : 'text-gray-600 hover:text-gray-900'
              }`}
            >
              <History className="w-4 h-4" />
              <span>History</span>
            </button>
            <button
              onClick={() => setView('settings')}
              className={`flex items-center space-x-2 px-6 py-4 font-medium transition ${
                view === 'settings'
                  ? 'text-indigo-600 border-b-2 border-indigo-600'
                  : 'text-gray-600 hover:text-gray-900'
              }`}
            >
              <SettingsIcon className="w-4 h-4" />
              <span>Settings</span>
            </button>
          </div>
        </div>
      </nav>

      <main className="max-w-7xl mx-auto px-4 py-8">
        {view === 'dashboard' && (
          <TransactionForm transactions={transactions} settings={settings} />
        )}
        {view === 'history' && (
          <TransactionHistory transactions={transactions} settings={settings} />
        )}
        {view === 'settings' && settings && (
          <Settings settings={settings} />
        )}
      </main>
    </div>
  );
}
