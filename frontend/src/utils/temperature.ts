export const celsiusToFahrenheit = (celsius: number): number => (celsius * 9) / 5 + 32;

export const formatTemperatureScale = (
  value: number | null | undefined,
  precision = 0,
): { celsius: string; fahrenheit: string } => {
  const normalized = Number.isFinite(Number(value)) ? Number(value) : 0;

  return {
    celsius: `${normalized.toFixed(precision)}°C`,
    fahrenheit: `${celsiusToFahrenheit(normalized).toFixed(precision)}°F`,
  };
};
