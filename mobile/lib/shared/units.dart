/// Canonical unit-conversion factors for body measurements. Stored values are
/// always metric (cm / kg); imperial is a display-time conversion only.
library;

const double cmPerInch = 2.54;
const double kgPerLb = 0.45359237;

double inToCm(double inches) => inches * cmPerInch;
double cmToIn(double cm) => cm / cmPerInch;
double lbsToKg(double lbs) => lbs * kgPerLb;
double kgToLbs(double kg) => kg / kgPerLb;
