module.exports = {
  root: true,
  env: {
    es6: true,
    node: true,
  },
  extends: [
    "eslint:recommended",
    "google",
  ],
  parserOptions: {
    ecmaVersion: 2022,
  },
  rules: {
    "quotes": ["error", "double"],
    "indent": ["error", 4],
    "object-curly-spacing": ["error", "never"],
    "max-len": ["error", {"code": 100, "ignoreStrings": true, "ignoreTemplateLiterals": true}],
  },
};
