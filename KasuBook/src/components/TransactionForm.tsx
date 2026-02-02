import { useState } from 'react';
import { useAuth } from '../contexts/AuthContext';
import { TransactionType, PaymentMethod, Tag, TAG_COLORS, Transaction, UserSettings } from '../types';
import { PlusCircle, Wallet, Smartphone, Banknote } from 'lucide-react';
import { db } from '../lib/firebase';
import { collection, addDoc } from 'firebase/firestore';

interface TransactionFormProps {
  transactions: Transaction[];
  settings: UserSettings | null;
}

const TAGS: Tag[] = ['Food', 'Snacks', 'Travel', 'Friends', 'Shopping', 'Bills', 'Entertainment', 'Health', 'Others'];

export default function TransactionForm({ transactions, settings }: TransactionFormProps) {
  const { user } = useAuth();
  const [type, setType] = useState<TransactionType>('expense');
  const [amount, setAmount] = useState('');
  const [paymentMethod, setPaymentMethod] = useState<PaymentMethod>('UPI');
  const [tag, setTag] = useState<Tag>('Food');
  const [description, setDescription] = useState('');
  const [transactionDate, setTransactionDate] = useState(new Date().toISOString().split('T')[0]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!user) return;

    setLoading(true);
    setError('');

    try {
      await addDoc(collection(db, 'users', user.uid, 'transactions'), {
        user_id: user.uid,
        type,
        amount: parseFloat(amount),
        payment_method: paymentMethod,
        tag,
        description,
        transaction_date: transactionDate
      });

      setAmount('');
      setDescription('');
      setTransactionDate(new Date().toISOString().split('T')[0]);
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

  const calculateStats = () => {
    const totalIncome = transactions
      .filter(t => t.type === 'income')
      .reduce((sum, t) => sum + Number(t.amount), 0);

    const totalExpense = transactions
      .filter(t => t.type === 'expense')
      .reduce((sum, t) => sum + Number(t.amount), 0);

    const balance = Number(settings?.initial_amount || 0) + totalIncome - totalExpense;

    const upiBalance = transactions
      .filter(t => t.payment_method === 'UPI')
      .reduce((sum, t) => sum + (t.type === 'income' ? Number(t.amount) : -Number(t.amount)), 0);

    const cashBalance = transactions
      .filter(t => t.payment_method === 'Cash')
      .reduce((sum, t) => sum + (t.type === 'income' ? Number(t.amount) : -Number(t.amount)), 0);

    return { balance, upiBalance, cashBalance };
  };

  const stats = calculateStats();

  return (
    <div className="space-y-6">
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div className="bg-gradient-to-br from-indigo-400 to-purple-600 rounded-xl p-6 text-white shadow-lg">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-indigo-100 text-sm mb-1">Total Amount</p>
              <p className="text-2xl font-bold">₹{stats.balance.toFixed(2)}</p>
            </div>
            <Wallet className="w-10 h-10 text-indigo-100" />
          </div>
        </div>

        <div className="bg-gradient-to-br from-blue-400 to-blue-600 rounded-xl p-6 text-white shadow-lg">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-blue-100 text-sm mb-1">UPI Amount</p>
              <p className="text-2xl font-bold">₹{stats.upiBalance.toFixed(2)}</p>
            </div>
            <Smartphone className="w-10 h-10 text-blue-100" />
          </div>
        </div>

        <div className="bg-gradient-to-br from-green-400 to-green-600 rounded-xl p-6 text-white shadow-lg">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-green-100 text-sm mb-1">Cash Amount</p>
              <p className="text-2xl font-bold">₹{stats.cashBalance.toFixed(2)}</p>
            </div>
            <Banknote className="w-10 h-10 text-green-100" />
          </div>
        </div>
      </div>

      <div className="bg-white rounded-xl shadow-lg p-6">
        <h2 className="text-xl font-bold text-gray-800 mb-6">Add Transaction</h2>

        <form onSubmit={handleSubmit} className="space-y-4">
          <div className="flex space-x-4">
            <button
              type="button"
              onClick={() => setType('income')}
              className={`flex-1 py-3 rounded-lg font-medium transition ${
                type === 'income'
                  ? 'bg-green-500 text-white'
                  : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
              }`}
            >
              Income
            </button>
            <button
              type="button"
              onClick={() => setType('expense')}
              className={`flex-1 py-3 rounded-lg font-medium transition ${
                type === 'expense'
                  ? 'bg-red-500 text-white'
                  : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
              }`}
            >
              Expense
            </button>
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Amount
            </label>
            <input
              type="number"
              step="0.01"
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
              className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-transparent outline-none transition"
              placeholder="0.00"
              required
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Payment Method
            </label>
            <div className="flex space-x-4">
              <button
                type="button"
                onClick={() => setPaymentMethod('UPI')}
                className={`flex-1 py-2 rounded-lg font-medium transition ${
                  paymentMethod === 'UPI'
                    ? 'bg-indigo-500 text-white'
                    : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
                }`}
              >
                UPI
              </button>
              <button
                type="button"
                onClick={() => setPaymentMethod('Cash')}
                className={`flex-1 py-2 rounded-lg font-medium transition ${
                  paymentMethod === 'Cash'
                    ? 'bg-indigo-500 text-white'
                    : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
                }`}
              >
                Cash
              </button>
            </div>
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Tag
            </label>
            <select
              value={tag}
              onChange={(e) => setTag(e.target.value as Tag)}
              className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-transparent outline-none transition"
            >
              {TAGS.map((t) => (
                <option key={t} value={t}>
                  {t}
                </option>
              ))}
            </select>
            <div className="mt-2 flex flex-wrap gap-2">
              {TAGS.map((t) => (
                <button
                  key={t}
                  type="button"
                  onClick={() => setTag(t)}
                  className={`px-3 py-1 rounded-full text-sm font-medium transition ${
                    TAG_COLORS[t]
                  } ${tag === t ? 'ring-2 ring-offset-2 ring-indigo-500' : ''}`}
                >
                  {t}
                </button>
              ))}
            </div>
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Date
            </label>
            <input
              type="date"
              value={transactionDate}
              onChange={(e) => setTransactionDate(e.target.value)}
              className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-transparent outline-none transition"
              required
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Description (Optional)
            </label>
            <textarea
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-transparent outline-none transition"
              rows={3}
              placeholder="Add a note..."
            />
          </div>

          {error && (
            <div className="bg-red-50 text-red-600 px-4 py-2 rounded-lg text-sm">
              {error}
            </div>
          )}

          <button
            type="submit"
            disabled={loading}
            className="w-full bg-gradient-to-r from-indigo-500 to-purple-600 text-white py-3 rounded-lg font-medium hover:from-indigo-600 hover:to-purple-700 transition disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center space-x-2"
          >
            <PlusCircle className="w-5 h-5" />
            <span>{loading ? 'Adding...' : 'Add Transaction'}</span>
          </button>
        </form>
      </div>
    </div>
  );
}
