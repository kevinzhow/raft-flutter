param(
  [Parameter(Mandatory=$true)][string]$InspectionDirectory,
  [Parameter(Mandatory=$true)][string]$SignedFile,
  [Parameter(Mandatory=$true)][string]$ExpectedThumbprint
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Security.Cryptography.Pkcs
$metadata = Get-Content (Join-Path $InspectionDirectory 'inspection.json') -Raw | ConvertFrom-Json
$cms = [System.Security.Cryptography.Pkcs.SignedCms]::new()
$cms.Decode([IO.File]::ReadAllBytes((Join-Path $InspectionDirectory 'signature.p7b')))
if ($cms.SignerInfos.Count -ne 1 -or $cms.ContentInfo.ContentType.Value -ne '1.3.6.1.4.1.311.2.1.4') {
  throw 'Expected one Authenticode CMS signer'
}
# Signature-only verification: do not install the TEST certificate in any store.
$cms.CheckSignature($true)
$certificate = $cms.SignerInfos[0].Certificate
if ($certificate.Thumbprint -ne $ExpectedThumbprint -or $certificate.Subject -ne $certificate.Issuer) {
  throw 'The signing result did not use the pinned self-signed TEST certificate'
}
if ([DateTime]::UtcNow -lt $certificate.NotBefore.ToUniversalTime() -or
    [DateTime]::UtcNow -gt $certificate.NotAfter.ToUniversalTime()) {
  throw 'TEST certificate is outside its validity period'
}
$reader = [System.Formats.Asn1.AsnReader]::new(
  [System.ReadOnlyMemory[byte]]$cms.ContentInfo.Content,
  [System.Formats.Asn1.AsnEncodingRules]::DER)
$content = $reader.ReadSequence()
$null = $content.ReadEncodedValue() # SpcAttributeTypeAndOptionalValue
$digestInfo = $content.ReadSequence()
$algorithm = $digestInfo.ReadSequence()
if ($algorithm.ReadObjectIdentifier() -ne '2.16.840.1.101.3.4.2.1') {
  throw 'This test workflow accepts SHA256 Authenticode only'
}
if ($algorithm.HasData) { $algorithm.ReadNull() }
$algorithm.ThrowIfNotEmpty()
$digest = [Convert]::ToHexString($digestInfo.ReadOctetString()).ToLowerInvariant()
$digestInfo.ThrowIfNotEmpty(); $content.ThrowIfNotEmpty(); $reader.ThrowIfNotEmpty()
if ($digest -ne $metadata.authenticodeSHA256) { throw 'Authenticode image digest mismatch' }
$signature = Get-AuthenticodeSignature -LiteralPath $SignedFile
if ($signature.SignerCertificate.Thumbprint -ne $ExpectedThumbprint -or
    $signature.Status -in @('NotSigned', 'HashMismatch', 'NotSupportedFileFormat')) {
  throw 'Windows did not recognize the expected embedded signature'
}
@{
  certificateSHA1 = $certificate.Thumbprint
  selfSignedTestCertificate = $true
  cmsSignatureVerified = $true
  authenticodeDigestVerified = $true
  payloadPreserved = $metadata.payloadPreserved
  windowsTrustStatus = "$($signature.Status)"
  note = 'TEST ONLY. No trust-store installation and no release publication.'
} | ConvertTo-Json | Set-Content (Join-Path $InspectionDirectory 'test-signature-result.json') -Encoding utf8
