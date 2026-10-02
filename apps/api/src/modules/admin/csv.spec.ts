import { csvCell, toCsv } from './csv.js';

describe('admin CSV export', () => {
  it('keeps text that would start a spreadsheet formula as text', () => {
    expect(csvCell('=HYPERLINK("http://x","click")')).toBe(`"'=HYPERLINK(""http://x"",""click"")"`);
    expect(csvCell('+91 1+1')).toBe("'+91 1+1");
    expect(csvCell('-2+3')).toBe("'-2+3");
    expect(csvCell('@SUM(A1)')).toBe("'@SUM(A1)");
    expect(csvCell('\tcmd')).toBe("'\tcmd");
  });

  it('leaves numbers, dates and plain text alone', () => {
    expect(csvCell(-5)).toBe('-5');
    expect(csvCell('+919876543210')).toBe('+919876543210');
    expect(csvCell(132)).toBe('132');
    expect(csvCell(new Date('2026-10-02T10:00:00Z'))).toBe('2026-10-02T10:00:00.000Z');
    expect(csvCell('Gandhipuram')).toBe('Gandhipuram');
    expect(csvCell(null)).toBe('');
    expect(csvCell('a, b')).toBe('"a, b"');
  });

  it('writes a header line from the first row', () => {
    expect(toCsv([{ id: 'a', name: '=1+1' }, { id: 'b', name: 'Selvi' }])).toBe("id,name\na,'=1+1\nb,Selvi");
    expect(toCsv([])).toBe('');
  });
});
