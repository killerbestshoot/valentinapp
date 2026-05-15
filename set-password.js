const admin = require('firebase-admin');
const path = require('path');

const serviceAccount = require(path.resolve(__dirname, 'serviceAccountKey.json'));

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

async function run() {
  const email = 'staffexcelsior3@gmail.com';
  const newPassword = '123456';

  const user = await admin.auth().getUserByEmail(email);

  await admin.auth().updateUser(user.uid, {
    password: newPassword,
  });

  console.log('PASSWORD CHANJE OK');
  console.log('EMAIL:', email);
  console.log('UID:', user.uid);
}

run().catch((e) => {
  console.error('ERÈ:', e.message || e);
  process.exit(1);
});
