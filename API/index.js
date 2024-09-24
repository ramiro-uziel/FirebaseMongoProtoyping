const express = require('express');
const admin = require('firebase-admin');
const { MongoClient } = require('mongodb');

const app = express();
app.use(express.json());

const MONGOURL = "mongodb://localhost:27017"
const DBNAME = "Bufetec"
const COLLECTION = "Users"
const PORT = 4000
const serviceAccount = require('./creds.json');

// Firebase Admin SDK
admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

// Cliente MongoDB
const mongoClient = new MongoClient(MONGOURL);
let db;
let usersCollection;

async function connectToMongo() {
    await mongoClient.connect();
    db = mongoClient.db(DBNAME);
    usersCollection = db.collection(COLLECTION);
}
connectToMongo().catch(console.error);

// Middleware para token de Firebase ID 
async function verifyToken(req, res, next) {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
        return res.status(401).json({ error: "Invalid Authorization header" });
    }

    const idToken = authHeader.split(' ')[1];

    try {
        const decodedToken = await admin.auth().verifyIdToken(idToken);
        req.user = decodedToken;
        next();
    } catch (error) {
        res.status(401).json({ error: "Authentication failed", details: error.message });
    }
}

// Post para crear usuario en MongoDB
app.post('/api/user', verifyToken, async (req, res) => {
    try {
        const { uid } = req.user;
        const updateData = req.body || {};
        const user = await usersCollection.findOne({ _id: uid });

        if (user) {
            await usersCollection.updateOne({ _id: uid }, { $set: updateData });
        } else {
            const newUser = {
                _id: uid,
                email: req.user.email || '',
                name: updateData.name || '',
                phone: updateData.phone || '',
            };
            await usersCollection.insertOne(newUser);
        }

        const updatedUser = await usersCollection.findOne({ _id: uid });
        res.status(user ? 200 : 201).json(updatedUser);
    } catch (error) {
        res.status(500).json({ error: "Internal server error", details: error.message });
    }
});

// Get para obtener info de usuario de MongoDB
app.get('/api/user', verifyToken, async (req, res) => {
    try {
        const { uid } = req.user;
        const user = await usersCollection.findOne({ _id: uid });

        if (user) {
            res.status(200).json(user);
        } else {
            res.status(404).json({ error: "User not found" });
        }
    } catch (error) {
        res.status(500).json({ error: "Internal server error", details: error.message });
    }
});

/* Se requiere para que Firebase no sobreescriba el provider
de autenticación de email con la cuenta de Google

Podriamos cambiarlo para que envie un correo de verificación
*/
app.post('/api/verifyEmail', verifyToken, async (req, res) => {
    try {
        const { uid } = req.user;

        await admin.auth().updateUser(uid, { emailVerified: true });

        await usersCollection.updateOne(
            { _id: uid },
            { $set: { email_verified: true } }
        );

        res.status(200).json({ message: "Email verified successfully" });
    } catch (error) {
        res.status(500).json({ error: "Internal server error", details: error.message });
    }
});

app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
});