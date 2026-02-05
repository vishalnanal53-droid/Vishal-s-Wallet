import { useState } from 'react';
import { useAuth } from '../contexts/AuthContext';
import { TransactionType, PaymentMethod, TAG_COLORS, Transaction, UserSettings } from '../types';
import { PlusCircle, Wallet, Smartphone, Banknote, Plus, X } from 'lucide-react';
import { db } from '../lib/firebase';
import { collection, addDoc, doc, updateDoc, arrayUnion, arrayRemove } from 'firebase/firestore';

interface TransactionFormProps {
  transactions: Transaction[];
  settings: UserSettings | null;
}

const DEFAULT_TAGS: string[] = ['Food', 'Snacks', 'Travel', 'Friends', 'Shopping', 'Bills', 'Entertainment', 'Health', 'Others'];

export default function TransactionForm({ transactions, settings }: TransactionFormProps) {
  const { user } = useAuth();
  const [type, setType] = useState<TransactionType>('expense');
  const [amount, setAmount] = useState('');
  const [paymentMethod, setPaymentMethod] = useState<PaymentMethod>('UPI');
  const [tag, setTag] = useState<string>('Food');
  const [newTag, setNewTag] = useState('');
  const [isAddingTag, setIsAddingTag] = useState(false);
  const [description, setDescription] = useState('');
  const [transactionDate, setTransactionDate] = useState(new Date().toISOString().split('T')[0]);
  const [transactionTime, setTransactionTime] = useState(new Date().toTimeString().slice(0, 5));
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!user) return;

    if (!description.trim()) {
      setError('Description is required');
      return;
    }

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
        transaction_date: transactionDate,
        transaction_time: transactionTime
      });

      setAmount('');
      setDescription('');
      setTransactionDate(new Date().toISOString().split('T')[0]);
      setTransactionTime(new Date().toTimeString().slice(0, 5));
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

  const customTags = (settings as any)?.custom_tags || [];
  const allTags = [...DEFAULT_TAGS, ...customTags];

  const handleAddTag = async () => {
    if (!newTag.trim() || !user) return;
    const tagToAdd = newTag.trim();
    // Capitalize first letter
    const formattedTag = tagToAdd.charAt(0).toUpperCase() + tagToAdd.slice(1);
    
    if (allTags.includes(formattedTag)) {
      setNewTag('');
      setIsAddingTag(false);
      setTag(formattedTag);
      return;
    }

    try {
      await updateDoc(doc(db, 'users', user.uid), {
        custom_tags: arrayUnion(formattedTag)
      });
      setNewTag('');
      setIsAddingTag(false);
      setTag(formattedTag);
    } catch (err) {
      console.error("Error adding tag:", err);
      setError("Failed to add tag");
    }
  };

  const handleDeleteTag = async (tagToDelete: string, e: React.MouseEvent) => {
    e.stopPropagation();
    if (!user) return;
    
    if (!confirm(`Are you sure you want to delete the tag "${tagToDelete}"?`)) return;

    try {
      await updateDoc(doc(db, 'users', user.uid), {
        custom_tags: arrayRemove(tagToDelete)
      });
      if (tag === tagToDelete) setTag(DEFAULT_TAGS[0]);
    } catch (err) {
      console.error("Error deleting tag:", err);
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

    return { 
      balance, 
      upiBalance: upiBalance + ((settings as any)?.initial_upi || 0), 
      cashBalance: cashBalance + ((settings as any)?.initial_cash || 0) 
    };
  };

  const stats = calculateStats();

  return (
    <div className="space-y-6">
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
              onChange={(e) => setTag(e.target.value)}
              className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-transparent outline-none transition"
            >
              {allTags.map((t) => (
                <option key={t} value={t}>
                  {t}
                </option>
              ))}
            </select>
            <div className="mt-2 flex flex-wrap gap-2">
              {allTags.map((t) => (
                <button
                  key={t}
                  type="button"
                  onClick={() => setTag(t)}
                  className={`group relative px-3 py-1 rounded-full text-sm font-medium transition ${
                    (TAG_COLORS as any)[t] || 'bg-gray-100 text-gray-800'
                  } ${tag === t ? 'ring-2 ring-offset-2 ring-indigo-500' : ''}`}
                >
                  {t}
                  {!DEFAULT_TAGS.includes(t) && (
                    <span 
                        onClick={(e) => handleDeleteTag(t, e)}
                        className="ml-2 -mr-1 p-0.5 rounded-full hover:bg-red-200 text-red-600 opacity-0 group-hover:opacity-100 transition-opacity inline-flex items-center justify-center"
                        title="Delete Tag"
                    >
                        <X className="w-3 h-3" />
                    </span>
                  )}
                </button>
              ))}
              
              {isAddingTag ? (
                <div className="flex items-center space-x-2">
                    <input 
                        type="text" 
                        value={newTag}
                        onChange={(e) => setNewTag(e.target.value)}
                        className="px-3 py-1 border border-gray-300 rounded-full text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 w-32"
                        placeholder="New tag..."
                        autoFocus
                        onKeyDown={(e) => {
                            if (e.key === 'Enter') {
                                e.preventDefault();
                                handleAddTag();
                            } else if (e.key === 'Escape') {
                                setIsAddingTag(false);
                            }
                        }}
                    />
                    <button type="button" onClick={handleAddTag} className="p-1 bg-green-100 text-green-600 rounded-full hover:bg-green-200">
                        <Plus className="w-4 h-4" />
                    </button>
                    <button type="button" onClick={() => setIsAddingTag(false)} className="p-1 bg-red-100 text-red-600 rounded-full hover:bg-red-200">
                        <X className="w-4 h-4" />
                    </button>
                </div>
              ) : (
                <button
                  type="button"
                  onClick={() => setIsAddingTag(true)}
                  className="px-3 py-1 rounded-full text-sm font-medium bg-gray-100 text-gray-600 hover:bg-gray-200 border border-dashed border-gray-400 flex items-center"
                >
                  <Plus className="w-3 h-3 mr-1" /> Add
                </button>
              )}
            </div>
          </div>

          <div className="flex space-x-4">
            <div className="flex-1">
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
            <div className="flex-1">
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Time
              </label>
              <input
                type="time"
                value={transactionTime}
                onChange={(e) => setTransactionTime(e.target.value)}
                className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-transparent outline-none transition"
                required
              />
            </div>
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Description
            </label>
            <textarea
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-transparent outline-none transition"
              rows={3}
              placeholder="Add a note..."
              required
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
