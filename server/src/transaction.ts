import { query } from "./db.ts";
import type { Device } from "./auth.ts";
import {
  Environment,
  SignedDataVerifier,
} from "npm:@apple/app-store-server-library@1.5.0";

// StoreKit 2 hands the app a transaction that Apple has already signed. We
// verify that signature locally against Apple's root certificates, so no
// credential of ours lives on this box and no round trip to Apple is needed.
//
// The alternative — trusting a client-supplied entitlement — would let anyone
// claim Plus and spend our AI budget, so every failure path below denies.

const BUNDLE_ID = "ren.startkind";
const APP_APPLE_ID = 6799113108;
const PLUS_PRODUCTS = new Set(["StartKind_plus_monthly", "StartKind_plus_yearly"]);

const ROOT_CERT_FILES = [
  "AppleRootCA-G3.cer",
  "AppleRootCA-G2.cer",
  "AppleIncRootCertificate.cer",
];

let verifiers: SignedDataVerifier[] | null = null;

async function loadVerifiers(): Promise<SignedDataVerifier[]> {
  if (verifiers) return verifiers;
  const roots: Uint8Array[] = [];
  for (const file of ROOT_CERT_FILES) {
    roots.push(await Deno.readFile(new URL(`../certs/${file}`, import.meta.url)));
  }
  // A sandbox (TestFlight) transaction and a production one are signed for
  // different environments, so keep one verifier for each and try both.
  verifiers = [
    new SignedDataVerifier(roots, true, Environment.PRODUCTION, BUNDLE_ID, APP_APPLE_ID),
    new SignedDataVerifier(roots, true, Environment.SANDBOX, BUNDLE_ID, APP_APPLE_ID),
  ];
  return verifiers;
}

type DecodedTransaction = {
  productId?: string;
  expiresDate?: number;
  revocationDate?: number;
  offerType?: number;
  offerDiscountType?: string;
};

/// Verify a StoreKit 2 signed transaction and store the entitlement it proves.
export async function verifyTransaction(
  device: Device,
  body: { signedTransaction?: unknown },
): Promise<{ status: number; body: Record<string, unknown> }> {
  const signed = body.signedTransaction;
  if (typeof signed !== "string" || signed.length === 0) {
    return { status: 400, body: { error: "bad_request" } };
  }

  let payload: DecodedTransaction | null = null;
  for (const verifier of await loadVerifiers()) {
    try {
      payload = await verifier.verifyAndDecodeTransaction(signed) as DecodedTransaction;
      break;
    } catch {
      // Wrong environment or an invalid signature; try the next verifier.
    }
  }
  // Nothing verified: deny. Never fall back to trusting the client.
  if (!payload) return { status: 400, body: { error: "verification_failed" } };

  const state = entitlementFor(payload);

  const written = await query(
    "UPDATE devices SET entitlement = $1 WHERE id = $2 RETURNING id",
    [state, device.id],
  );
  if (written.length === 0) {
    return { status: 500, body: { error: "entitlement_write_failed" } };
  }

  return { status: 200, body: { state } };
}

function entitlementFor(payload: DecodedTransaction): string {
  if (!payload.productId || !PLUS_PRODUCTS.has(payload.productId)) return "free";
  // A refunded or upgraded-away transaction grants nothing.
  if (payload.revocationDate) return "free";

  const expires = payload.expiresDate ?? 0;
  if (expires <= Date.now()) return "plus_expired";

  // offerType 1 is an introductory offer. Only the FREE_TRIAL flavour is a
  // trial; PAY_AS_YOU_GO and PAY_UP_FRONT are paid intro pricing.
  const isFreeTrial = payload.offerType === 1 &&
    (payload.offerDiscountType === undefined || payload.offerDiscountType === "FREE_TRIAL");
  return isFreeTrial ? "plus_trial" : "plus_active";
}
