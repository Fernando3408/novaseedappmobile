class MockGreenhouseCross {
  const MockGreenhouseCross({required this.code, required this.mother, required this.father, required this.berries, required this.target, required this.status});
  final String code;
  final String mother;
  final String father;
  final int berries;
  final int target;
  final String status;
}

const mockCrosses = [
  MockGreenhouseCross(code: 'C-014', mother: 'Línea M-08', father: 'Línea P-12', berries: 26, target: 40, status: 'EN CURSO'),
  MockGreenhouseCross(code: 'C-021', mother: 'Línea M-11', father: 'Línea P-04', berries: 40, target: 40, status: 'LISTO'),
];

const mockPositions = [
  ('07', 'C-013', 'Revisada'),
  ('08', 'C-014', 'Por revisar'),
  ('09', 'C-018', 'Por revisar'),
  ('10', 'C-021', 'Revisada'),
];
