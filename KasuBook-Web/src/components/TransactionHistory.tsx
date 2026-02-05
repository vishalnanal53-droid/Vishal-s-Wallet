import { useState } from 'react';
import { Transaction, TAG_COLORS, UserSettings } from '../types';
import { Search, Filter, Calendar, Download, FileText, Table as TableIcon } from 'lucide-react';
import jsPDF from 'jspdf';
import autoTable from 'jspdf-autotable';
import * as ExcelJS from 'exceljs';
import { saveAs } from 'file-saver';

interface TransactionHistoryProps {
  transactions: Transaction[];
  settings?: UserSettings | null;
}

type TimeFilter = 'all' | 'today' | 'week' | 'month' | 'year' | 'custom';

export default function TransactionHistory({ transactions, settings }: TransactionHistoryProps) {
  const [searchQuery, setSearchQuery] = useState('');
  const [timeFilter, setTimeFilter] = useState<TimeFilter>('all');
  const [tagFilter, setTagFilter] = useState<string>('all');
  const [customStartDate, setCustomStartDate] = useState('');
  const [customEndDate, setCustomEndDate] = useState('');

  // Calculate running balances (Chronological then reversed)
  const transactionsWithBalance = [...transactions].reverse().reduce((acc: any[], t: any) => {
    const prev = acc.length > 0 ? acc[acc.length - 1] : {
      cashBalance: (settings as any)?.initial_cash || 0,
      upiBalance: (settings as any)?.initial_upi || 0
    };

    let newCash = prev.cashBalance;
    let newUpi = prev.upiBalance;
    const amount = Number(t.amount);

    if (t.payment_method === 'Cash') {
      newCash = t.type === 'income' ? newCash + amount : newCash - amount;
    } else {
      newUpi = t.type === 'income' ? newUpi + amount : newUpi - amount;
    }

    acc.push({ ...t, cashBalance: newCash, upiBalance: newUpi });
    return acc;
  }, []).reverse();

  const filterTransactions = () => {
    let filtered = [...transactionsWithBalance];

    if (searchQuery) {
      filtered = filtered.filter(
        (t) =>
          t.description.toLowerCase().includes(searchQuery.toLowerCase()) ||
          t.tag.toLowerCase().includes(searchQuery.toLowerCase())
      );
    }

    if (tagFilter !== 'all') {
      filtered = filtered.filter((t) => t.tag === tagFilter);
    }

    const now = new Date();
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());

    switch (timeFilter) {
      case 'today':
        filtered = filtered.filter((t) => new Date(t.transaction_date) >= today);
        break;
      case 'week': {
        const weekAgo = new Date(today);
        weekAgo.setDate(weekAgo.getDate() - 7);
        filtered = filtered.filter((t) => new Date(t.transaction_date) >= weekAgo);
        break;
      }
      case 'month': {
        const monthAgo = new Date(today);
        monthAgo.setMonth(monthAgo.getMonth() - 1);
        filtered = filtered.filter((t) => new Date(t.transaction_date) >= monthAgo);
        break;
      }
      case 'year': {
        const yearAgo = new Date(today);
        yearAgo.setFullYear(yearAgo.getFullYear() - 1);
        filtered = filtered.filter((t) => new Date(t.transaction_date) >= yearAgo);
        break;
      }
      case 'custom':
        if (customStartDate && customEndDate) {
          filtered = filtered.filter((t) => {
            const date = new Date(t.transaction_date);
            return date >= new Date(customStartDate) && date <= new Date(customEndDate);
          });
        }
        break;
    }

    return filtered;
  };

  const filteredTransactions = filterTransactions();

  const totalIncome = filteredTransactions
    .filter((t) => t.type === 'income')
    .reduce((sum, t) => sum + Number(t.amount), 0);

  const totalExpense = filteredTransactions
    .filter((t) => t.type === 'expense')
    .reduce((sum, t) => sum + Number(t.amount), 0);

  const uniqueTags = Array.from(new Set([
    ...Object.keys(TAG_COLORS),
    ...transactions.map(t => t.tag),
    ...((settings as any)?.custom_tags || [])
  ])).sort();

  const downloadPDF = () => {
    const doc = new jsPDF();
    
    doc.setFontSize(18);
    doc.text('Transaction History', 14, 22);
    doc.setFontSize(11);
    doc.text(`Generated on: ${new Date().toLocaleDateString()}`, 14, 30);

    const tableData = filteredTransactions.map((t, index) => [
      index + 1,
      t.transaction_date,
      t.transaction_time || '-',
      t.description,
      `Rs.${Number(t.amount).toFixed(2)}`,
      t.type === 'income' ? `Rs.${Number(t.amount).toFixed(2)}` : '-',
      t.type === 'expense' ? `Rs.${Number(t.amount).toFixed(2)}` : '-',
      `Rs.${t.cashBalance.toFixed(2)}`,
      `Rs.${t.upiBalance.toFixed(2)}`
    ]);

    // Add Total Row
    tableData.push([
      '', '', '', 'TOTAL', '',
      `Rs.${totalIncome.toFixed(2)}`,
      `Rs.${totalExpense.toFixed(2)}`,
      '', ''
    ]);

    autoTable(doc, {
      head: [['SNo', 'Date', 'Time', 'Description', 'Amount', 'Credit', 'Debit', 'Cash Bal', 'UPI Bal']],
      body: tableData,
      startY: 35,
      theme: 'grid',
      styles: { fontSize: 8 },
      headStyles: { fillColor: [79, 70, 229] }
    });

    // Summary
    const finalY = (doc as any).lastAutoTable.finalY + 10;
    doc.text('Statement Summary:', 14, finalY);
    doc.text(`Total Income (Credit): Rs.${totalIncome.toFixed(2)}`, 14, finalY + 8);
    doc.text(`Total Expense (Debit): Rs.${totalExpense.toFixed(2)}`, 14, finalY + 16);
    doc.text(`Net Balance Change: Rs.${(totalIncome - totalExpense).toFixed(2)}`, 14, finalY + 24);

    doc.save('kasubook_history.pdf');
  };

  const downloadExcel = async () => {
    const workbook = new ExcelJS.Workbook();
    const worksheet = workbook.addWorksheet('Transactions');

    worksheet.columns = [
      { header: 'SNo', key: 'sno', width: 8 },
      { header: 'Date', key: 'date', width: 12 },
      { header: 'Time', key: 'time', width: 10 },
      { header: 'Description', key: 'description', width: 30 },
      { header: 'Amount', key: 'amount', width: 12 },
      { header: 'Credit', key: 'credit', width: 12 },
      { header: 'Debit', key: 'debit', width: 12 },
      { header: 'Cash Balance', key: 'cashBalance', width: 15 },
      { header: 'UPI Balance', key: 'upiBalance', width: 15 },
    ];

    filteredTransactions.forEach((t, index) => {
      worksheet.addRow({
        sno: index + 1,
        date: t.transaction_date,
        time: t.transaction_time || '-',
        description: t.description,
        amount: Number(t.amount),
        credit: t.type === 'income' ? Number(t.amount) : 0,
        debit: t.type === 'expense' ? Number(t.amount) : 0,
        cashBalance: t.cashBalance,
        upiBalance: t.upiBalance
      });
    });

    // Add Total Row
    worksheet.addRow({
      sno: '', date: '', time: '', description: 'TOTAL',
      amount: '', credit: totalIncome, debit: totalExpense,
      cashBalance: '', upiBalance: ''
    });

    // Add Summary
    worksheet.addRow([]);
    worksheet.addRow(['Statement Summary:']);
    worksheet.addRow([`Total Income (Credit): Rs.${totalIncome.toFixed(2)}`]);
    worksheet.addRow([`Total Expense (Debit): Rs.${totalExpense.toFixed(2)}`]);
    worksheet.addRow([`Net Balance Change: Rs.${(totalIncome - totalExpense).toFixed(2)}`]);

    const buffer = await workbook.xlsx.writeBuffer();
    saveAs(new Blob([buffer]), "kasubook_history.xlsx");
  };

  return (
    <div className="space-y-6">
      <div className="bg-white rounded-xl shadow-lg p-6">
        <div className="flex flex-col md:flex-row justify-between items-start md:items-center mb-6 gap-4">
          <h2 className="text-xl font-bold text-gray-800">Transaction History</h2>
          <div className="flex gap-2">
            <button onClick={downloadExcel} className="flex items-center px-3 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition text-sm"><TableIcon className="w-4 h-4 mr-2"/> Excel</button>
            <button onClick={downloadPDF} className="flex items-center px-3 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition text-sm"><FileText className="w-4 h-4 mr-2"/> PDF</button>
          </div>
        </div>

        <div className="space-y-4">
          <div className="relative">
            <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400 w-5 h-5" />
            <input
              type="text"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              placeholder="Search transactions..."
              className="w-full pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-transparent outline-none transition"
            />
          </div>

          <div className="flex flex-col sm:flex-row gap-4">
            <div className="flex-1">
              <label className="block text-sm font-medium text-gray-700 mb-1 flex items-center">
                <Calendar className="w-4 h-4 mr-1" />
                Time Period
              </label>
              <select
                value={timeFilter}
                onChange={(e) => setTimeFilter(e.target.value as TimeFilter)}
                className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-transparent outline-none transition"
              >
                <option value="all">All Time</option>
                <option value="today">Today</option>
                <option value="week">Last 7 Days</option>
                <option value="month">Last 30 Days</option>
                <option value="year">Last Year</option>
                <option value="custom">Custom Range</option>
              </select>
            </div>

            <div className="flex-1">
              <label className="block text-sm font-medium text-gray-700 mb-1 flex items-center">
                <Filter className="w-4 h-4 mr-1" />
                Tag Filter
              </label>
              <select
                value={tagFilter}
                onChange={(e) => setTagFilter(e.target.value)}
                className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-transparent outline-none transition"
              >
                <option value="all">All Tags</option>
                {uniqueTags.map((tag) => (
                  <option key={tag} value={tag}>
                    {tag}
                  </option>
                ))}
              </select>
            </div>
          </div>

          {timeFilter === 'custom' && (
            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Start Date
                </label>
                <input
                  type="date"
                  value={customStartDate}
                  onChange={(e) => setCustomStartDate(e.target.value)}
                  className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-transparent outline-none transition"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  End Date
                </label>
                <input
                  type="date"
                  value={customEndDate}
                  onChange={(e) => setCustomEndDate(e.target.value)}
                  className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-transparent outline-none transition"
                />
              </div>
            </div>
          )}
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div className="bg-green-50 border border-green-200 rounded-xl p-4">
          <p className="text-green-600 text-sm font-medium mb-1">Total Income</p>
          <p className="text-2xl font-bold text-green-700">₹{totalIncome.toFixed(2)}</p>
        </div>
        <div className="bg-red-50 border border-red-200 rounded-xl p-4">
          <p className="text-red-600 text-sm font-medium mb-1">Total Expense</p>
          <p className="text-2xl font-bold text-red-700">₹{totalExpense.toFixed(2)}</p>
        </div>
      </div>

      <div className="bg-white rounded-xl shadow-lg overflow-hidden">
        {filteredTransactions.length === 0 ? (
          <div className="p-12 text-center text-gray-500">
            <p>No transactions found</p>
          </div>
        ) : (
          <div className="divide-y divide-gray-200">
            {filteredTransactions.map((transaction) => (
              <div
                key={transaction.id}
                className="p-4 hover:bg-gray-50 transition flex items-center justify-between"
              >
                <div className="flex-1">
                  <div className="flex items-center space-x-3 mb-2">
                    <span
                      className={`px-3 py-1 rounded-full text-xs font-medium ${
                        (TAG_COLORS as any)[transaction.tag] || 'bg-gray-100 text-gray-800'
                      }`}
                    >
                      {transaction.tag}
                    </span>
                    <span className="text-xs text-gray-500">{transaction.payment_method}</span>
                  </div>
                  {transaction.description && (
                    <p className="text-gray-700 mb-1">{transaction.description}</p>
                  )}
                  <p className="text-xs text-gray-500">
                    {new Date(transaction.transaction_date).toLocaleDateString('en-IN', {
                      year: 'numeric',
                      month: 'long',
                      day: 'numeric',
                    })}
                    {transaction.transaction_time && ` • ${transaction.transaction_time}`}
                  </p>
                </div>
                <div className="flex items-center space-x-4">
                  <p
                    className={`text-xl font-bold ${
                      transaction.type === 'income' ? 'text-green-600' : 'text-red-600'
                    }`}
                  >
                    {transaction.type === 'income' ? '+' : '-'}₹{Number(transaction.amount).toFixed(2)}
                  </p>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
