/**
 * @param hexValue sting hex value. Example: "345abcdef10001"
 */
export function addHexPrefix(hexValue: string): string {
    const paddedHexValue = hexValue.padStart((hexValue.length + 1) & ~1, "0");
    return "0x" + paddedHexValue;
}