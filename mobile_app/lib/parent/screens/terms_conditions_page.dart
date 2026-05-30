import 'package:flutter/material.dart';

class TermsConditionsPage extends StatelessWidget {
  const TermsConditionsPage({super.key});

  static const _lorem =
      'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do '
      'eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad '
      'minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip '
      'ex ea commodo consequat. Duis aute irure dolor in reprehenderit in '
      'voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur '
      'sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt '
      'mollit anim id est laborum.\n\n'
      'Sed ut perspiciatis unde omnis iste natus error sit voluptatem '
      'accusantium doloremque laudantium, totam rem aperiam, eaque ipsa quae ab '
      'illo inventore veritatis et quasi architecto beatae vitae dicta sunt '
      'explicabo. Nemo enim ipsam voluptatem quia voluptas sit aspernatur aut '
      'odit aut fugit, sed quia consequuntur magni dolores eos qui ratione '
      'voluptatem sequi nesciunt. Neque porro quisquam est, qui dolorem ipsum '
      'quia dolor sit amet, consectetur, adipisci velit.\n\n'
      'At vero eos et accusamus et iusto odio dignissimos ducimus qui '
      'blanditiis praesentium voluptatum deleniti atque corrupti quos dolores '
      'et quas molestias excepturi sint occaecati cupiditate non provident, '
      'similique sunt in culpa qui officia deserunt mollitia animi, id est '
      'laborum et dolorum fuga.\n\n'
      'Nam libero tempore, cum soluta nobis est eligendi optio cumque nihil '
      'impedit quo minus id quod maxime placeat facere possimus, omnis voluptas '
      'assumenda est, omnis dolor repellendus. Temporibus autem quibusdam et '
      'aut officiis debitis aut rerum necessitatibus saepe eveniet ut et '
      'voluptates repudiandae sint et molestiae non recusandae.\n\n'
      'Quis autem vel eum iure reprehenderit qui in ea voluptate velit esse '
      'quam nihil molestiae consequatur, vel illum qui dolorem eum fugiat quo '
      'voluptas nulla pariatur.';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSection('1. Acceptance of Terms', _lorem),
                    const SizedBox(height: 20),
                    _buildSection('2. Use of the Service', _lorem),
                    const SizedBox(height: 20),
                    _buildSection('3. Account Responsibilities', _lorem),
                    const SizedBox(height: 20),
                    _buildSection('4. Payment & Wallet', _lorem),
                    const SizedBox(height: 20),
                    _buildSection('5. Termination', _lorem),
                    const SizedBox(height: 20),
                    _buildSection('6. Governing Law', _lorem),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 20, 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back_ios,
              size: 20,
              color: Color(0xFF1A1A1A),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TERMS & CONDITIONS',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.8,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Last updated: May 2026',
                style: TextStyle(fontSize: 11, color: Color(0xFF9B9B9B)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String heading, String body) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          heading,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          body,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF4A4A4A),
            height: 1.65,
          ),
        ),
      ],
    );
  }
}
