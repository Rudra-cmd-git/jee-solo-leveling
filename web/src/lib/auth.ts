import { supabase } from './supabase';
import { User } from '@supabase/supabase-js';

// Auth utility functions
export const signIn = async (email: string, password: string) => {
  const { data, error } = await supabase.auth.signInWithPassword({
    email,
    password,
  });

  if (error) throw error;
  return data;
};

export const signUp = async (email: string, password: string, name: string) => {
  const { data, error } = await supabase.auth.signUp({
    email,
    password,
    options: {
      data: {
        name,
      },
    },
  });

  if (error) throw error;
  return data;
};

export const signOut = async () => {
  const { error } = await supabase.auth.signOut();

  if (error) throw error;
};

export const getUser = async () => {
  const { data: { user }, error } = await supabase.auth.getUser();

  if (error) throw error;
  return user;
};

export const updateUser = async (userData: { name?: string }) => {
  const { data, error } = await supabase.auth.updateUser({
    data: userData,
  });

  if (error) throw error;
  return data;
};

// Auth state listener
export const onAuthStateChange = (callback: (user: User | null) => void) => {
  return supabase.auth.onAuthStateChange((_event, session) => {
    callback(session?.user ?? null);
  });
};