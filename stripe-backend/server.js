require('dotenv').config();
const express = require('express');
const Stripe = require('stripe');
const cors = require('cors');

const app = express();
const stripe = Stripe(process.env.STRIPE_SECRET_KEY);

app.use(cors());
app.use(express.json());

app.get('/', (_, res) => res.send('MealConnect Stripe backend OK'));

app.post('/create-payment-intent', async (req, res) => {
  try {
    const { amountCents } = req.body;
    if (!Number.isInteger(amountCents) || amountCents < 50) {
      return res.status(400).json({ error: 'Minimum amount is $0.50' });
    }
    const intent = await stripe.paymentIntents.create({
      amount: amountCents,
      currency: 'usd',
      automatic_payment_methods: { enabled: true },
    });
    res.json({ clientSecret: intent.client_secret });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`MealConnect Stripe backend running on port ${PORT}`));
