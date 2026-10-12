const fs = require("node:fs");
const path = require("node:path");

const SECTOR_SIZE = 2048;
const FLOPPY_SIZE = 1474560;
const FLOPPY_SECTORS = FLOPPY_SIZE / SECTOR_SIZE;
const projectRoot = path.resolve(__dirname, "..");
const outputDirectory = path.join(projectRoot, "dist");

function fail(message) {
  console.error(`Build error: ${message}`);
  process.exit(1);
}

function readRequired(name) {
  const file = path.join(outputDirectory, name);
  if (!fs.existsSync(file)) fail(`Missing ${name}; run build.ps1 first.`);
  return fs.readFileSync(file);
}

function sectorsFor(bytes) {
  return Math.ceil(bytes / SECTOR_SIZE);
}

function putBothEndian32(buffer, offset, value) {
  buffer.writeUInt32LE(value, offset);
  buffer.writeUInt32BE(value, offset + 4);
}

function dateTime7(date = new Date()) {
  return Buffer.from([
    date.getUTCFullYear() - 1900,
    date.getUTCMonth() + 1,
    date.getUTCDate(),
    date.getUTCHours(),
    date.getUTCMinutes(),
    date.getUTCSeconds(),
    0,
  ]);
}

function isoDateTime17(date = new Date()) {
  const digits = [
    date.getUTCFullYear(),
    String(date.getUTCMonth() + 1).padStart(2, "0"),
    String(date.getUTCDate()).padStart(2, "0"),
    String(date.getUTCHours()).padStart(2, "0"),
    String(date.getUTCMinutes()).padStart(2, "0"),
    String(date.getUTCSeconds()).padStart(2, "0"),
    "00",
  ].join("");
  return Buffer.from(`${digits}\0`, "ascii");
}

function directoryRecord(extent, size, identifier, flags = 0) {
  const name = Buffer.isBuffer(identifier) ? identifier : Buffer.from(identifier, "ascii");
  const length = 33 + name.length + (name.length % 2 === 0 ? 1 : 0);
  const record = Buffer.alloc(length);
  record[0] = length;
  record[1] = 0;
  putBothEndian32(record, 2, extent);
  putBothEndian32(record, 10, size);
  dateTime7().copy(record, 18);
  record[25] = flags;
  record[26] = 0;
  record[27] = 0;
  record.writeUInt16LE(1, 28);
  record.writeUInt16BE(1, 30);
  record[32] = name.length;
  name.copy(record, 33);
  return record;
}

function writeDirectoryEntry(buffer, offset, record) {
  if (offset + record.length > buffer.length) fail("Root directory exceeds one sector.");
  record.copy(buffer, offset);
  return offset + record.length;
}

function pathTable(littleEndian, rootExtent) {
  const table = Buffer.alloc(10);
  table[0] = 1;
  table[1] = 0;
  if (littleEndian) {
    table.writeUInt32LE(rootExtent, 2);
    table.writeUInt16LE(1, 6);
  } else {
    table.writeUInt32BE(rootExtent, 2);
    table.writeUInt16BE(1, 6);
  }
  table[8] = 0;
  return table;
}

function writeIso(bootImage, readme) {
  const rootSector = 21;
  const bootCatalogSector = 22;
  const floppySector = 23;
  const readmeSector = floppySector + FLOPPY_SECTORS;
  const volumeSectors = readmeSector + sectorsFor(readme.length);
  const iso = Buffer.alloc(volumeSectors * SECTOR_SIZE);

  const pvd = iso.subarray(16 * SECTOR_SIZE, 17 * SECTOR_SIZE);
  pvd[0] = 1;
  pvd.write("CD001", 1, "ascii");
  pvd[6] = 1;
  pvd[8] = 0;
  pvd.write("LUMENOS", 40, 32, "ascii");
  pvd.writeUInt32LE(volumeSectors, 80);
  pvd.writeUInt32BE(volumeSectors, 84);
  pvd.writeUInt16LE(1, 120);
  pvd.writeUInt16BE(1, 122);
  pvd.writeUInt16LE(1, 124);
  pvd.writeUInt16BE(1, 126);
  pvd.writeUInt16LE(SECTOR_SIZE, 128);
  pvd.writeUInt16BE(SECTOR_SIZE, 130);
  pvd.writeUInt32LE(10, 132);
  pvd.writeUInt32BE(10, 136);
  pvd.writeUInt32LE(19, 140);
  pvd.writeUInt32LE(0, 144);
  pvd.writeUInt32BE(20, 148);
  pvd.writeUInt32BE(0, 152);
  directoryRecord(rootSector, SECTOR_SIZE, Buffer.from([0]), 2).copy(pvd, 156);
  pvd.write("LUMENOS", 190, 128, "ascii");
  pvd.write("LUMENOS BUILD", 446, 128, "ascii");
  pvd.write("LUMENOS 0.1", 574, 128, "ascii");
  for (const offset of [813, 830, 847, 864]) isoDateTime17().copy(pvd, offset);
  pvd[881] = 1;

  const bootRecord = iso.subarray(17 * SECTOR_SIZE, 18 * SECTOR_SIZE);
  bootRecord[0] = 0;
  bootRecord.write("CD001", 1, "ascii");
  bootRecord[6] = 1;
  bootRecord.write("EL TORITO SPECIFICATION", 7, "ascii");
  bootRecord.writeUInt32LE(bootCatalogSector, 71);

  const terminator = iso.subarray(18 * SECTOR_SIZE, 19 * SECTOR_SIZE);
  terminator[0] = 255;
  terminator.write("CD001", 1, "ascii");
  terminator[6] = 1;

  pathTable(true, rootSector).copy(iso, 19 * SECTOR_SIZE);
  pathTable(false, rootSector).copy(iso, 20 * SECTOR_SIZE);

  const rootDirectory = iso.subarray(rootSector * SECTOR_SIZE, (rootSector + 1) * SECTOR_SIZE);
  let offset = 0;
  offset = writeDirectoryEntry(rootDirectory, offset, directoryRecord(rootSector, SECTOR_SIZE, Buffer.from([0]), 2));
  offset = writeDirectoryEntry(rootDirectory, offset, directoryRecord(rootSector, SECTOR_SIZE, Buffer.from([1]), 2));
  offset = writeDirectoryEntry(rootDirectory, offset, directoryRecord(floppySector, FLOPPY_SIZE, "LUMENOS.IMG;1"));
  writeDirectoryEntry(rootDirectory, offset, directoryRecord(readmeSector, readme.length, "README.TXT;1"));

  const catalog = iso.subarray(bootCatalogSector * SECTOR_SIZE, (bootCatalogSector + 1) * SECTOR_SIZE);
  catalog[0] = 1;
  catalog[1] = 0;
  catalog.write("EL TORITO SPECIFICATION", 4, "ascii");
  catalog[30] = 0x55;
  catalog[31] = 0xaa;
  const entry = 32;
  catalog[entry] = 0x88;
  catalog[entry + 1] = 2;
  catalog.writeUInt16LE(0, entry + 2);
  catalog[entry + 4] = 0;
  catalog.writeUInt16LE(1, entry + 6);
  catalog.writeUInt32LE(floppySector, entry + 8);
  let checksum = 0;
  for (let i = 0; i < 32; i += 2) checksum = (checksum + catalog.readUInt16LE(i)) & 0xffff;
  catalog.writeUInt16LE((-checksum) & 0xffff, 28);

  bootImage.copy(iso, floppySector * SECTOR_SIZE);
  readme.copy(iso, readmeSector * SECTOR_SIZE);
  return iso;
}

const boot = readRequired("boot.bin");
const kernel = readRequired("kernel.bin");
if (boot.length !== 512 || boot.readUInt16LE(510) !== 0xaa55) {
  fail("boot.bin must be exactly 512 bytes and end with the 0xAA55 signature.");
}
if (kernel.length > 17 * 512) {
  fail(`kernel.bin is ${kernel.length} bytes; the bootloader can load at most ${17 * 512}.`);
}

const floppy = Buffer.alloc(FLOPPY_SIZE);
boot.copy(floppy, 0);
kernel.copy(floppy, 512);
fs.writeFileSync(path.join(outputDirectory, "LumenOS.img"), floppy);

const readme = Buffer.from(
  "LumenOS 0.1\n" +
    "==========\n\n" +
    "A tiny, standalone 16-bit x86 real-mode operating-system demonstration.\n" +
    "The CD image boots via legacy BIOS El Torito floppy emulation (1.44 MB).\n\n" +
    "Commands: help, about, version, memory, clear, reboot, halt, hello\n\n" +
    "C++ shell commands are implemented in src/user.cpp.\n" +
    "Rebuild the image after changing the C++ source.\n\n" +
    "Boot LumenOS.iso in a virtual machine configured for legacy BIOS/CSM.\n" +
    "UEFI-only boot is not supported by this first release.\n",
  "ascii",
);
const iso = writeIso(floppy, readme);
fs.writeFileSync(path.join(outputDirectory, "LumenOS.iso"), iso);

console.log(`Created LumenOS.img (${floppy.length.toLocaleString()} bytes)`);
console.log(`Created LumenOS.iso (${iso.length.toLocaleString()} bytes)`);
