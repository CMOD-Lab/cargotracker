// PostCSS configuration used by the css-minifier Docker build stage (cz-css-1004).
// cssnano removes whitespace, comments, and optimises selectors for production.
module.exports = {
  plugins: [
    require('cssnano')({
      preset: ['default', {
        discardComments: { removeAll: true },
        normalizeWhitespace: true,
        minifySelectors: true,
        minifyParams: true,
        reduceIdents: false
      }]
    })
  ]
};
