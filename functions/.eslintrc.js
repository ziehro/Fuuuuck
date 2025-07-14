module.exports = {
  root: true,
  env: {
    es6: true,
    node: true,
  },
  extends: [
    "eslint:recommended",
  ],
  parserOptions: {
    ecmaVersion: 2020,
  },
  rules: {
    "quotes": ["error", "double"],
    "indent": ["error", 2],
    "max-len": ["error", { "code": 100 }],
    "comma-dangle": ["error", "only-multiline"],
    "no-trailing-spaces": "error",
    "eol-last": ["error", "always"]
  },
};