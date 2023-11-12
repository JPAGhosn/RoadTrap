import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'homeview.dart';

class SignInView extends StatelessWidget {

  final _emailController = TextEditingController(text: "jp.abighosn.98@gmail.com");
  final _passwordController = TextEditingController(text: "Password");
  final _formKey = GlobalKey<FormState>();
  final _auth = FirebaseAuth.instance;

  SignInView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  "Sign In",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 30
                  ),
                ),
                SizedBox(height: 25),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15.0),
                  child: TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      hintText: 'Enter your email address',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter an email';
                      }
                      return null;
                    },
                  ),
                ),
                SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15.0),
                  child: TextFormField(
                    obscureText: true,
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      hintText: 'Enter your password',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a password';
                      }
                      return null;
                    },
                  ),
                ),
                SizedBox(height: 15,),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15.0),
                  child: SizedBox(height: 50, child: ElevatedButton(onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      try {
                        final creds = await _auth.signInWithEmailAndPassword(
                          email: _emailController.text.trim(),
                          password: _passwordController.text.trim(),
                        );

                        if (creds.user!.emailVerified == false) {
                          await creds.user!.sendEmailVerification();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("We've sent you a new verification email")),
                          );
                          return;
                        }

                        // Navigate to next page or show success message
                      } on FirebaseAuthException catch (e) {
                        // Handle error, maybe show a snackbar with the error message
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(e.message!)),
                        );
                      }
                      catch(e) {
                        print(e);
                      }
                    }
                  }, child: Text("Sign In"))),
                )
              ],
            ),
          )
      ),
    );
  }
}
