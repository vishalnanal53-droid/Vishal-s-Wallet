import { initializeApp } from "firebase/app";
import { getAuth } from "firebase/auth";
import { getFirestore } from "firebase/firestore";

const firebaseConfig = {
  apiKey: "AIzaSyDvSwVUFKiQOUJNEqFuHp4O_o2mthRdCGM",
  authDomain: "kasubook.firebaseapp.com",
  projectId: "kasubook",
  storageBucket: "kasubook.firebasestorage.app",
  messagingSenderId: "654865930698",
  appId: "1:654865930698:web:38f4cf7b65c3f7f56fd733",
  measurementId: "G-G9HXP92JSD"
};

const app = initializeApp(firebaseConfig);
export const auth = getAuth(app);
export const db = getFirestore(app);