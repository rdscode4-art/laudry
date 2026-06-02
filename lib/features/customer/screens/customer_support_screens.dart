import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/colors.dart';
import '../controllers/customer_controller.dart';
import '../widgets/customer_shared_widgets.dart';

class ReferralScreen extends StatelessWidget {
  const ReferralScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final code = CustomerController.instance.referralCode.value;
    return Scaffold(
      appBar: AppBar(title: const Text('Referral & Bonus')),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
        Container(padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF0D2B5E), kAccentBlue]), borderRadius: BorderRadius.circular(20)),
          child: Column(children: [
            const Icon(Icons.card_giftcard_outlined, color: Colors.white, size: 48),
            const SizedBox(height: 12),
            const Text('Your Referral Code', style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 8),
            Text(code, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 4)),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              ElevatedButton.icon(
                onPressed: () { Clipboard.setData(ClipboardData(text: code)); Get.snackbar('Copied', 'Code copied!', snackPosition: SnackPosition.BOTTOM, backgroundColor: kAccentGreen, colorText: Colors.white); },
                icon: const Icon(Icons.copy, size: 16), label: const Text('Copy'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.2), foregroundColor: Colors.white),
              ),
              ElevatedButton.icon(
                onPressed: () => Get.snackbar('Share', 'Sharing referral link...', snackPosition: SnackPosition.BOTTOM, backgroundColor: kAccentBlue, colorText: Colors.white),
                icon: const Icon(Icons.share, size: 16), label: const Text('Share'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.2), foregroundColor: Colors.white),
              ),
            ]),
          ])),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: customerCard(child: const Column(children: [
            Text('0', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: kAccentBlue)),
            Text('Friends Referred', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ]))),
          const SizedBox(width: 12),
          Expanded(child: customerCard(child: const Column(children: [
            Text('₹0', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: kAccentGreen)),
            Text('Total Earned', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ]))),
        ]),
        customerCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('How it works', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: kPrimaryBlue)),
          const SizedBox(height: 12),
          _refStep('1', 'Share your referral code with friends', kAccentBlue),
          _refStep('2', 'Friend signs up & places first order', kOrange),
          _refStep('3', 'You earn ₹50 bonus in your wallet', kAccentGreen),
          _refStep('4', 'Your friend gets ₹30 discount too!', Colors.purple),
        ])),
        customerCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Referral History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: kPrimaryBlue)),
          const SizedBox(height: 12),
          _refRow('Priya S.', '20 May', '₹50', true),
          _refRow('Amit V.', '15 May', '₹50', true),
          _refRow('Neha G.', 'Pending', '₹50', false),
        ])),
      ])),
    );
  }
  Widget _refStep(String num, String text, Color color) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(children: [
    Container(width: 28, height: 28, decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle), child: Center(child: Text(num, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13)))),
    const SizedBox(width: 12), Expanded(child: Text(text, style: const TextStyle(fontSize: 13, color: kPrimaryBlue))),
  ]));
  Widget _refRow(String name, String date, String amount, bool paid) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [
    CircleAvatar(radius: 16, backgroundColor: kAccentBlue.withOpacity(0.1), child: Text(name[0], style: const TextStyle(color: kAccentBlue, fontWeight: FontWeight.bold))),
    const SizedBox(width: 10),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: kPrimaryBlue)),
      Text(date, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
    ])),
    Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: paid ? kAccentGreen.withOpacity(0.1) : kOrange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
        child: Text(paid ? amount : 'Pending', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: paid ? kAccentGreen : kOrange))),
  ]));
}

class ComplaintScreen extends StatefulWidget {
  const ComplaintScreen({super.key});
  @override State<ComplaintScreen> createState() => _ComplaintScreenState();
}
class _ComplaintScreenState extends State<ComplaintScreen> {
  final _sc = TextEditingController(), _dc = TextEditingController();
  String _cat = 'Damaged Clothes'; bool _submitted = false;
  final _cats = ['Damaged Clothes', 'Missing Items', 'Late Delivery', 'Wrong Order', 'Quality Issue', 'Other'];
  @override void dispose() { _sc.dispose(); _dc.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final ctrl = CustomerController.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('Complaint Ticket')),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Obx(() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (ctrl.complaints.isNotEmpty) ...[
          const Text('My Tickets', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: kPrimaryBlue)),
          const SizedBox(height: 8),
          ...ctrl.complaints.map((c) => customerCard(child: Row(children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.support_agent, color: Colors.red, size: 20)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c['subject'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: kPrimaryBlue)),
              Text(c['category'] as String, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            ])),
            Builder(builder: (ctx) {
              final status = c['status'] as String? ?? 'Open';
              Color cColor = status == 'Resolved' || status == 'Closed' ? kAccentGreen : (status == 'In Progress' ? kPrimaryBlue : kOrange);
              return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: cColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Text(status, style: TextStyle(fontSize: 11, color: cColor, fontWeight: FontWeight.bold)));
            }),
          ]))),
        ],
        const Text('Raise New Ticket', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: kPrimaryBlue)),
        const SizedBox(height: 8),
        customerCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Category', style: TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: _cats.map((cat) {
            final sel = cat == _cat;
            return GestureDetector(onTap: () => setState(() => _cat = cat), child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: sel ? kAccentBlue : Colors.grey.shade100, borderRadius: BorderRadius.circular(20), border: Border.all(color: sel ? kAccentBlue : Colors.grey.shade300)),
              child: Text(cat, style: TextStyle(fontSize: 12, color: sel ? Colors.white : kPrimaryBlue, fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
            ));
          }).toList()),
          const SizedBox(height: 14),
          TextFormField(controller: _sc, decoration: const InputDecoration(labelText: 'Subject', prefixIcon: Icon(Icons.title_outlined))),
          const SizedBox(height: 12),
          TextFormField(controller: _dc, maxLines: 4, decoration: const InputDecoration(labelText: 'Describe your issue', alignLabelWithHint: true)),
          const SizedBox(height: 16),
          if (_submitted)
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: kAccentGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: const Row(children: [Icon(Icons.check_circle_outline, color: kAccentGreen), SizedBox(width: 8), Expanded(child: Text('Ticket submitted! We\'ll respond in 24 hrs.', style: TextStyle(color: kAccentGreen, fontWeight: FontWeight.w600)))]))
          else
            ElevatedButton.icon(
              onPressed: () {
                if (_sc.text.trim().isEmpty) { Get.snackbar('Error', 'Please enter a subject', snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red, colorText: Colors.white); return; }
                ctrl.addComplaint(_sc.text, _cat, _dc.text);
                setState(() { _submitted = true; _sc.clear(); _dc.clear(); });
              },
              icon: const Icon(Icons.send_outlined), label: const Text('Submit Ticket'),
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48), backgroundColor: Colors.red.shade600),
            ),
        ])),
      ]))),
    );
  }
}

class RatingScreen extends StatefulWidget {
  final String orderId;
  const RatingScreen({super.key, required this.orderId});
  @override State<RatingScreen> createState() => _RatingScreenState();
}
class _RatingScreenState extends State<RatingScreen> {
  int _stars = 0; bool _submitted = false;
  final _rc = TextEditingController();
  @override void dispose() { _rc.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final existing = CustomerController.instance.orderRatings[widget.orderId];
    return Scaffold(
      appBar: AppBar(title: Text('Rate ${widget.orderId}')),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (existing != null || _submitted)
          customerCard(child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (i) => Icon(i < (existing ?? _stars) ? Icons.star : Icons.star_border, color: kOrange, size: 36))),
            const SizedBox(height: 12),
            Text(existing != null ? 'You rated this order ${existing}★' : 'Thank you for your feedback!', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: kPrimaryBlue)),
            if (_rc.text.isNotEmpty) ...[const SizedBox(height: 8), Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: kOrange.withOpacity(0.07), borderRadius: BorderRadius.circular(10)),
                child: Row(children: [const Icon(Icons.format_quote, color: kOrange, size: 16), const SizedBox(width: 8), Expanded(child: Text(_rc.text, style: const TextStyle(fontSize: 13, color: kPrimaryBlue)))]))],
          ]))
        else ...[
          customerCard(child: Column(children: [
            const Text('Overall Rating', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: kPrimaryBlue)),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (i) => GestureDetector(onTap: () => setState(() => _stars = i + 1),
                child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Icon(i < _stars ? Icons.star : Icons.star_border, color: kOrange, size: 40))))),
            const SizedBox(height: 8),
            Text(_stars == 0 ? 'Tap to rate' : ['', 'Poor', 'Fair', 'Good', 'Very Good', 'Excellent'][_stars],
                style: TextStyle(fontSize: 14, color: _stars > 0 ? kOrange : Colors.grey, fontWeight: FontWeight.w600)),
          ])),
          customerCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Write a Review', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: kPrimaryBlue)),
            const SizedBox(height: 10),
            TextFormField(controller: _rc, maxLines: 3, decoration: const InputDecoration(hintText: 'Share your experience...', border: OutlineInputBorder())),
          ])),
          ElevatedButton.icon(
            onPressed: _stars == 0 ? null : () {
              setState(() { CustomerController.instance.orderRatings[widget.orderId] = _stars; _submitted = true; });
              Get.snackbar('Rated', 'Thanks for rating $_stars★', snackPosition: SnackPosition.BOTTOM, backgroundColor: kOrange, colorText: Colors.white);
            },
            icon: const Icon(Icons.star_outlined), label: const Text('Submit Rating'),
            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52), backgroundColor: kOrange),
          ),
        ],
      ])),
    );
  }
}

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});
  Future<void> _openWA(BuildContext context) async {
    const phone = '919999999999';
    final name = CustomerController.instance.session.value?.name ?? 'Customer';
    final msg = Uri.encodeComponent('Hi RiDeal! I need help. Name: $name');
    final url = Uri.parse('https://wa.me/$phone?text=$msg');
    if (await canLaunchUrl(url)) { await launchUrl(url, mode: LaunchMode.externalApplication); }
    else { Get.snackbar('Error', 'WhatsApp not installed', snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red, colorText: Colors.white); }
  }
  @override
  Widget build(BuildContext context) {
    final faqs = [
      {'q': 'How do I track my order?',       'a': 'Go to Orders tab → tap your active order → Track Order.'},
      {'q': 'What is the pickup time?',        'a': 'Pickup happens within 2 hours. Choose a slot while booking.'},
      {'q': 'How do I cancel an order?',       'a': 'Contact us on WhatsApp before pickup is confirmed.'},
      {'q': 'What if my clothes are damaged?', 'a': 'Raise a complaint ticket from Profile → Complaint Ticket.'},
      {'q': 'How does wallet work?',           'a': 'Recharge your wallet and use it to pay for orders directly.'},
      {'q': 'How do I use referral code?',     'a': 'Share your code from Profile → Referral & Bonus. Earn ₹50 per referral.'},
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Support')),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        GestureDetector(onTap: () => _openWA(context), child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: const Color(0xFF25D366), borderRadius: BorderRadius.circular(18),
              boxShadow: [BoxShadow(color: const Color(0xFF25D366).withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 6))]),
          child: Row(children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.chat_outlined, color: Colors.white, size: 32)),
            const SizedBox(width: 16),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Chat on WhatsApp', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
              SizedBox(height: 4),
              Text('Typically replies within 5 minutes', style: TextStyle(color: Colors.white70, fontSize: 12)),
            ])),
            const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
          ]),
        )),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: customerCard(padding: const EdgeInsets.all(14), child: Column(children: [
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: kAccentBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.phone_outlined, color: kAccentBlue, size: 24)),
            const SizedBox(height: 8), const Text('Call Us', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: kPrimaryBlue)),
            const Text('+91 99999 99999', style: TextStyle(fontSize: 10, color: Colors.grey), textAlign: TextAlign.center),
          ]))),
          const SizedBox(width: 12),
          Expanded(child: customerCard(padding: const EdgeInsets.all(14), child: Column(children: [
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: kOrange.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.email_outlined, color: kOrange, size: 24)),
            const SizedBox(height: 8), const Text('Email Us', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: kPrimaryBlue)),
            const Text('support@rideal.in', style: TextStyle(fontSize: 10, color: Colors.grey), textAlign: TextAlign.center),
          ]))),
        ]),
        const SizedBox(height: 8),
        const Text('FAQs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: kPrimaryBlue)),
        const SizedBox(height: 8),
        ...faqs.map((f) => customerCard(padding: EdgeInsets.zero, child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          title: Text(f['q']!, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: kPrimaryBlue)),
          children: [Text(f['a']!, style: TextStyle(fontSize: 13, color: Colors.grey.shade600))],
        ))),
      ])),
    );
  }
}
