class MarketCategories {
  static const String pork = 'Pork';
  static const String poultry = 'Poultry';
  static const String beef = 'Beef';
  static const String vegetables = 'Vegetables';
  static const String fish = 'Fish';
  static const String dryGoods = 'Dry Goods';
  static const String fruits = 'Fruits';
  static const String seafood = 'Seafood';
  static const String condiments = 'Condiments';
  static const String other = 'Other';

  static const List<String> all = [
    pork,
    poultry,
    beef,
    vegetables,
    fish,
    dryGoods,
    fruits,
    seafood,
    condiments,
    other,
  ];

  static String getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'pork':
        return '🥩';
      case 'poultry':
        return '🍗';
      case 'beef':
        return '🥩';
      case 'vegetables':
        return '🥬';
      case 'fish':
        return '🐟';
      case 'dry goods':
        return '🌾';
      case 'fruits':
        return '🍎';
      case 'seafood':
        return '🦐';
      case 'condiments':
        return '🧂';
      default:
        return '🏪';
    }
  }
}
