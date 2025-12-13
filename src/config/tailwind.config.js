const defaultTheme = require('tailwindcss/defaultTheme')

module.exports = {
  content: [
    './public/*.html',
    './app/helpers/**/*.rb',
    './app/javascript/**/*.js',
    './app/views/**/*.{erb,haml,html,slim}',
    './app/models/**/*.rb'
  ],
  safelist: [
    // Facet colors - dynamically generated classes that need to be preserved
    // Organism (blue)
    'bg-blue-500', 'text-blue-500', 'text-blue-600', 'bg-blue-100', 'text-blue-800', 'bg-blue-50', 'focus:ring-blue-300', 'focus:ring-blue-500', 'hover:text-blue-800', 'hover:bg-blue-50',
    // Cell Type (green)
    'bg-green-500', 'text-green-500', 'text-green-600', 'bg-green-100', 'text-green-800', 'bg-green-50', 'focus:ring-green-300', 'focus:ring-green-500', 'hover:text-green-800', 'hover:bg-green-50',
    // Tissue (purple)
    'bg-purple-500', 'text-purple-500', 'text-purple-600', 'bg-purple-100', 'text-purple-800', 'bg-purple-50', 'focus:ring-purple-300', 'focus:ring-purple-500', 'hover:text-purple-800', 'hover:bg-purple-50',
    // Developmental Stage (orange)
    'bg-orange-500', 'text-orange-500', 'text-orange-600', 'bg-orange-100', 'text-orange-800', 'bg-orange-50', 'focus:ring-orange-300', 'focus:ring-orange-500', 'hover:text-orange-800', 'hover:bg-orange-50',
    // Disease (red)
    'bg-red-500', 'text-red-500', 'text-red-600', 'bg-red-100', 'text-red-800', 'bg-red-50', 'focus:ring-red-300', 'focus:ring-red-500', 'hover:text-red-800', 'hover:bg-red-50',
    // Sex (pink)
    'bg-pink-500', 'text-pink-500', 'text-pink-600', 'bg-pink-100', 'text-pink-800', 'bg-pink-50', 'focus:ring-pink-300', 'focus:ring-pink-500', 'hover:text-pink-800', 'hover:bg-pink-50',
    // Technology (indigo)
    'bg-indigo-500', 'text-indigo-500', 'text-indigo-600', 'bg-indigo-100', 'text-indigo-800', 'bg-indigo-50', 'focus:ring-indigo-300', 'focus:ring-indigo-500', 'hover:text-indigo-800', 'hover:bg-indigo-50',
    // Suspension Type (teal)
    'bg-teal-500', 'text-teal-500', 'text-teal-600', 'bg-teal-100', 'text-teal-800', 'bg-teal-50', 'focus:ring-teal-300', 'focus:ring-teal-500', 'hover:text-teal-800', 'hover:bg-teal-50',
    // Data Source (yellow)
    'bg-yellow-500', 'text-yellow-500', 'text-yellow-600', 'bg-yellow-100', 'text-yellow-800', 'bg-yellow-50', 'focus:ring-yellow-300', 'focus:ring-yellow-500', 'hover:text-yellow-800', 'hover:bg-yellow-50',
  ],
  theme: {
    extend: {
      fontFamily: {
        sans: ['Inter var', ...defaultTheme.fontFamily.sans],
      },
      colors: {
        'brand-dark': '#01081E',
        'brand-light': '#2D3B66'
      },
    },
  },
  plugins: [
    require('@tailwindcss/forms'),
    require('@tailwindcss/typography'),
    require('@tailwindcss/container-queries'),
  ]
}
