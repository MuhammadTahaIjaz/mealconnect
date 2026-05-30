require('dotenv').config();
const express = require('express');
const Stripe = require('stripe');
const cors = require('cors');

const app = express();
const stripe = Stripe(process.env.STRIPE_SECRET_KEY);

app.use(cors());
app.use(express.json());

app.get('/', (_, res) => res.send('MealConnect Stripe backend OK'));

// Create a Stripe customer for a parent (call once, store customerId in Firestore)
app.post('/create-customer', async (req, res) => {
  try {
    const { email, uid } = req.body;
    const customer = await stripe.customers.create({
      email,
      metadata: { uid },
    });
    res.json({ customerId: customer.id });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// List saved cards for a customer
app.post('/list-payment-methods', async (req, res) => {
  try {
    const { customerId } = req.body;
    const methods = await stripe.paymentMethods.list({
      customer: customerId,
      type: 'card',
    });
    res.json({ paymentMethods: methods.data });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Create a PaymentIntent
// - Pass customerId to link to a Stripe customer (card will be saved after payment)
// - Pass paymentMethodId to charge a previously saved card
app.post('/create-payment-intent', async (req, res) => {
  try {
    const { amountCents, customerId, paymentMethodId } = req.body;
    if (!Number.isInteger(amountCents) || amountCents < 50) {
      return res.status(400).json({ error: 'Minimum amount is $0.50' });
    }

    const params = {
      amount: amountCents,
      currency: 'usd',
    };

    if (customerId) {
      params.customer = customerId;
      // Saves the card to the customer after successful payment
      params.setup_future_usage = 'off_session';
      params.payment_method_types = ['card'];
    } else {
      params.automatic_payment_methods = { enabled: true };
    }

    if (paymentMethodId) {
      params.payment_method = paymentMethodId;
    }

    const intent = await stripe.paymentIntents.create(params);
    res.json({ clientSecret: intent.client_secret });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Delete a Stripe customer — call this before deleting a parent account
app.post('/delete-customer', async (req, res) => {
  try {
    const { customerId } = req.body;
    await stripe.customers.del(customerId);
    res.json({ deleted: true });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Create a Stripe Express connected account + onboarding link for a cafeteria
// Pass accountId if the cafeteria already has one (regenerates the link)
app.post('/create-account-link', async (req, res) => {
  try {
    const { cafeteriaId, email, accountId } = req.body;
    let stripeAccountId = accountId;

    if (!stripeAccountId) {
      const account = await stripe.accounts.create({
        type: 'express',
        email,
        metadata: { cafeteriaId },
        capabilities: { transfers: { requested: true } },
      });
      stripeAccountId = account.id;
    }

    const accountLink = await stripe.accountLinks.create({
      account: stripeAccountId,
      refresh_url: 'https://mealconnect.app/reauth',
      return_url: 'https://mealconnect.app/connect-return',
      type: 'account_onboarding',
    });

    res.json({ accountId: stripeAccountId, url: accountLink.url });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Transfer meal payment to cafeteria on delivery
app.post('/transfer-to-cafeteria', async (req, res) => {
  try {
    const { amountCents, cafeteriaAccountId, selectionId } = req.body;
    if (!amountCents || !cafeteriaAccountId) {
      return res.status(400).json({ error: 'Missing required fields' });
    }
    const transfer = await stripe.transfers.create({
      amount: amountCents,
      currency: 'usd',
      destination: cafeteriaAccountId,
      metadata: { selectionId: selectionId || '' },
    });
    res.json({ transferId: transfer.id });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`MealConnect Stripe backend running on port ${PORT}`));
