param(
  [Parameter(Mandatory = $true)]
  [string]$FileName
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

if (-not [Windows.Forms.Clipboard]::ContainsImage()) {
  Write-Error "Clipboard does not contain an image."
  exit 2
}

$Image = [Windows.Forms.Clipboard]::GetImage()
$Image.Save($FileName, [System.Drawing.Imaging.ImageFormat]::Png)
exit 0
