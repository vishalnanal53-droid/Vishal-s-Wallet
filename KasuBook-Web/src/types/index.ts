export type TransactionType = 'income' | 'expense';
export type PaymentMethod = 'UPI' | 'Cash';
export type Tag = 'Food' | 'Snacks' | 'Travel' | 'Friends' | 'Shopping' | 'Bills' | 'Entertainment' | 'Health' | 'Others';

export interface Transaction {
  id: string;
  user_id: string;
  type: TransactionType;
  amount: number;
  payment_method: PaymentMethod;
  tag: Tag;
  description: string;
  transaction_date: string;
  created_at: string;
}

export interface UserSettings {
  id: string;
  username: string;
  initial_amount: number;
  created_at: string;
  updated_at: string;
}

export const TAG_COLORS: Record<Tag, string> = {
  Food: 'bg-orange-100 text-orange-700',
  Snacks: 'bg-yellow-100 text-yellow-700',
  Travel: 'bg-blue-100 text-blue-700',
  Friends: 'bg-pink-100 text-pink-700',
  Shopping: 'bg-purple-100 text-purple-700',
  Bills: 'bg-red-100 text-red-700',
  Entertainment: 'bg-indigo-100 text-indigo-700',
  Health: 'bg-green-100 text-green-700',
  Others: 'bg-gray-100 text-gray-700',
};
