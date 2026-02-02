import { useState, useEffect } from 'react';
import { useAuth } from '../contexts/AuthContext';
import { supabase } from '../lib/supabase';
import { Transaction, UserSettings } from '../types';
import TransactionForm from './TransactionForm';
import TransactionHistory from './TransactionHistory';
import Settings from './Settings';
import { Wallet, History, Settings as SettingsIcon, LogOut } from 'lucide-react';

type View = 'dashboard' | 'history' | 'settings';

export default function Dashboard() {
  const { user, signOut } = useAuth();
  const [view, setView] = useState<View>('dashboard');
  const [transactions, setTransactions] = useState<Transaction[]>([]);
  const [settings, setSettings] = useState<UserSettings | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadData();
  }, [user]);

  const loadData = async () => {
    if (!user) return;

    try {
      const [settingsResponse, transactionsResponse] = await Promise.all([
        supabase.from('user_settings').select('*').eq('id', user.id).maybeSingle(),
        supabase.from('transactions').select('*').eq('user_id', user.id).order('transaction_date', { ascending: false })
      ]);

      if (settingsResponse.data) {
        setSettings(settingsResponse.data);
      } else {
        const newSettings = {
          id: user.id,
          username: 'User',
          initial_amount: 0,
        };
        await supabase.from('user_settings').insert(newSettings);
        setSettings({ ...newSettings, created_at: new Date().toISOString(), updated_at: new Date().toISOString() });
      }

      if (transactionsResponse.data) {
        setTransactions(transactionsResponse.data);
      }
    } catch (error) {
      console.error('Error loading data:', error);
    } finally {
      setLoading(false);
    }
  };

  const calculateBalance = () => {
    const totalIncome = transactions
      .filter(t => t.type === 'income')
      .reduce((sum, t) => sum + Number(t.amount), 0);

    const totalExpense = transactions
      .filter(t => t.type === 'expense')
      .reduce((sum, t) => sum + Number(t.amount), 0);

    return Number(settings?.initial_amount || 0) + totalIncome - totalExpense;
  };

  const handleLogout = async () => {
    try {
      await signOut();
    } catch (error) {
      console.error('Error signing out:', error);
    }
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
      <header className="bg-gradient-to-r from-indigo-500 via-purple-500 to-pink-500 text-white shadow-lg">
        <div className="max-w-7xl mx-auto px-4 py-6">
          <div className="flex items-center justify-between">
            <div className="flex items-center space-x-3">
              <div className="bg-white/20 p-2 rounded-lg backdrop-blur-sm">
                <Wallet className="w-6 h-6" />
              </div>
              <div>
                <h1 className="text-2xl font-bold">KasuBook</h1>
                <p className="text-sm text-white/80">Hello, {settings?.username || 'User'}!</p>
              </div>
            </div>
            <button
              onClick={handleLogout}
              className="flex items-center space-x-2 bg-white/20 hover:bg-white/30 px-4 py-2 rounded-lg transition backdrop-blur-sm"
            >
              <LogOut className="w-4 h-4" />
              <span>Logout</span>
            </button>
          </div>

          <div className="mt-6 bg-white/20 backdrop-blur-sm rounded-xl p-4">
            <p className="text-sm text-white/80 mb-1">Current Balance</p>
            <p className="text-3xl font-bold">₹{calculateBalance().toFixed(2)}</p>
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
          <TransactionForm onTransactionAdded={loadData} transactions={transactions} settings={settings} />
        )}
        {view === 'history' && (
          <TransactionHistory transactions={transactions} onRefresh={loadData} />
        )}
        {view === 'settings' && settings && (
          <Settings settings={settings} onUpdate={loadData} />
        )}
      </main>
    </div>
  );
}
