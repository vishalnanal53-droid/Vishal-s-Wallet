import { useState } from 'react';
import { UserSettings } from '../types';
import { Save, User, Smartphone, Banknote } from 'lucide-react';
import { db } from '../lib/firebase';
import { doc, updateDoc } from 'firebase/firestore';
import { useAuth } from '../contexts/AuthContext';

interface SettingsProps {
  settings: UserSettings;
}

export default function Settings({ settings }: SettingsProps) {
  const { user } = useAuth();
  const [username, setUsername] = useState(settings.username);
  const [initialCash, setInitialCash] = useState(((settings as any).initial_cash || 0).toString());
  const [initialUpi, setInitialUpi] = useState(((settings as any).initial_upi || 0).toString());
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState(false);

  const isInitialAmountLocked = (settings as any).initial_amount_locked || false;

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError('');
    setSuccess(false);

    const cash = parseFloat(initialCash) || 0;
    const upi = parseFloat(initialUpi) || 0;
    const total = cash + upi;

    try {
      if (user) {
        const updateData: any = {
          username,
          updated_at: new Date().toISOString(),
        };

        if (!isInitialAmountLocked) {
          updateData.initial_amount = total;
          updateData.initial_cash = cash;
          updateData.initial_upi = upi;
          updateData.initial_amount_locked = total > 0;
        }

        await updateDoc(doc(db, 'users', user.uid), updateData);
      }

      setSuccess(true);
      setTimeout(() => setSuccess(false), 3000);
    } catch (err) {
      if (err instanceof Error) {
        setError(err.message || 'An error occurred');
      } else {
        setError('An error occurred');
      }
    } finally {
      setLoading(false);
    }
  };

  const totalInitial = (parseFloat(initialCash) || 0) + (parseFloat(initialUpi) || 0);

  return (
    <div className="max-w-2xl mx-auto">
      <div className="bg-white rounded-xl shadow-lg p-6">
        <h2 className="text-xl font-bold text-gray-800 mb-6">Settings</h2>

        <form onSubmit={handleSubmit} className="space-y-6">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1 flex items-center">
              <User className="w-4 h-4 mr-2" />
              Username
            </label>
            <input
              type="text"
              value={username}
              onChange={(e) => setUsername(e.target.value)}
              className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-transparent outline-none transition"
              placeholder="Enter your name"
              required
            />
            <p className="mt-1 text-sm text-gray-500">
              This name will be displayed on your dashboard
            </p>
          </div>

          <div>
            <h3 className="text-sm font-medium text-gray-700 mb-3 flex items-center">
              ₹ Initial Balance Breakdown
              {isInitialAmountLocked && (
                <span className="ml-2 text-xs bg-amber-100 text-amber-800 px-2 py-0.5 rounded-full border border-amber-200">
                  Locked
                </span>
              )}
            </h3>
            
            <div className="mb-4 p-3 bg-blue-50 text-blue-700 text-xs rounded-lg border border-blue-100">
              
              <p>Enter the amount you currently have at the start. Once entered, this will be fixed. Any other changes should be added in your transaction.</p>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label className="block text-xs text-gray-500 mb-1 flex items-center">
                  <Banknote className="w-3 h-3 mr-1" /> Cash
                </label>
                <input
                  type="number"
                  step="0.01"
                  value={initialCash}
                  onChange={(e) => setInitialCash(e.target.value)}
                  className={`w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-transparent outline-none transition ${
                    isInitialAmountLocked ? 'bg-gray-100 text-gray-500 cursor-not-allowed' : ''
                  }`}
                  placeholder="0.00"
                  disabled={isInitialAmountLocked}
                />
              </div>
              <div>
                <label className="block text-xs text-gray-500 mb-1 flex items-center">
                  <Smartphone className="w-3 h-3 mr-1" /> UPI
                </label>
                <input
                  type="number"
                  step="0.01"
                  value={initialUpi}
                  onChange={(e) => setInitialUpi(e.target.value)}
                  className={`w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-transparent outline-none transition ${
                    isInitialAmountLocked ? 'bg-gray-100 text-gray-500 cursor-not-allowed' : ''
                  }`}
                  placeholder="0.00"
                  disabled={isInitialAmountLocked}
                />
              </div>
            </div>
            <p className="mt-2 text-sm text-gray-600 bg-gray-50 p-2 rounded-lg border border-gray-200">
              Total Initial Amount: <span className="font-bold">₹{totalInitial.toFixed(2)}</span>
            </p>
            <p className="mt-1 text-xs text-gray-500">
              Set your starting Cash and UPI balance separately.
            </p>
          </div>

          {error && (
            <div className="bg-red-50 text-red-600 px-4 py-2 rounded-lg text-sm">
              {error}
            </div>
          )}

          {success && (
            <div className="bg-green-50 text-green-600 px-4 py-2 rounded-lg text-sm">
              Settings updated successfully!
            </div>
          )}

          <button
            type="submit"
            disabled={loading}
            className="w-full bg-gradient-to-r from-indigo-500 to-purple-600 text-white py-3 rounded-lg font-medium hover:from-indigo-600 hover:to-purple-700 transition disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center space-x-2"
          >
            <Save className="w-5 h-5" />
            <span>{loading ? 'Saving...' : 'Save Settings'}</span>
          </button>
        </form>

        <div className="mt-8 p-4 bg-gray-50 rounded-lg">
          <h3 className="font-medium text-gray-800 mb-2">About KasuBook</h3>
          <p className="text-sm text-gray-600">
            KasuBook is your personal money management companion. Track your income and expenses,
            categorize transactions, and stay on top of your finances with ease.
          </p>
        </div>

        <div className="mt-4 p-4 bg-gray-50 rounded-lg">
          <h3 className="font-medium text-gray-800 mb-2">Terms and Conditions</h3>
          <p className="text-sm text-gray-600">
            By using KasuBook, you agree to track your expenses responsibly. 
            Data is stored securely on Firebase. We are not responsible for any financial discrepancies or data loss.
          </p>
        </div>
      </div>
    </div>
  );
}
