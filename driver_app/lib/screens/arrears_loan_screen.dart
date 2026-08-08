import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/driver_salary.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';

/// Lists the driver's Arrears Loans — deficits an admin converted into a
/// scheduled deduction against future salary (see the Deposit section on
/// the My Salary screen) — each with its full month-by-month split payment
/// schedule.
class ArrearsLoanScreen extends StatefulWidget {
  const ArrearsLoanScreen({super.key});

  @override
  State<ArrearsLoanScreen> createState() => _ArrearsLoanScreenState();
}

class _ArrearsLoanScreenState extends State<ArrearsLoanScreen> {
  late Future<List<ArrearsLoan>> _loansFuture;

  @override
  void initState() {
    super.initState();
    _loansFuture = ApiClient.instance.fetchArrearsLoans();
  }

  Future<void> _reload() async {
    final future = ApiClient.instance.fetchArrearsLoans();
    setState(() => _loansFuture = future);
    await future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Loan Arrears')),
      body: RefreshIndicator(
        color: AppColors.neon,
        backgroundColor: AppColors.surface,
        onRefresh: _reload,
        child: FutureBuilder<List<ArrearsLoan>>(
          future: _loansFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator(color: AppColors.neon));
            }

            if (snapshot.hasError) {
              return ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 100),
                    child: Column(
                      children: [
                        const Icon(Icons.error_outline, size: 44, color: AppColors.textMuted),
                        const SizedBox(height: 12),
                        Text(
                          snapshot.error.toString(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            final loans = snapshot.data ?? [];

            if (loans.isEmpty) {
              return ListView(
                children: const [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 100),
                    child: Column(
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 44, color: AppColors.textMuted),
                        SizedBox(height: 12),
                        Text(
                          'No arrears loans. These appear here if a shortfall on your '
                          'deposit balance is ever converted into a scheduled salary deduction.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: loans.length,
              itemBuilder: (context, index) => _ArrearsLoanCard(loan: loans[index]),
            );
          },
        ),
      ),
    );
  }
}

class _ArrearsLoanCard extends StatelessWidget {
  final ArrearsLoan loan;

  const _ArrearsLoanCard({required this.loan});

  @override
  Widget build(BuildContext context) {
    final sourceLabel = loan.sourceYear != null && loan.sourceMonth != null
        ? 'From ${DateFormat.yMMMM().format(DateTime(loan.sourceYear!, loan.sourceMonth!))}'
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '\$${loan.amount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    if (sourceLabel != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        sourceLabel,
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.neon.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  loan.deductionTypeLabel,
                  style: const TextStyle(color: AppColors.neon, fontSize: 10, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: AppColors.border, height: 1),
          ),
          const Text(
            'Deduction Schedule',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          ...loan.deductions.map(
            (d) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      DateFormat.yMMMM().format(DateTime(d.year, d.month)),
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                    ),
                  ),
                  Text(
                    '\$${d.amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
