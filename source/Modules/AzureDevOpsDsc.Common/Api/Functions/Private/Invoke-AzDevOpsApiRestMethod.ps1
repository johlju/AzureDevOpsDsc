<#
    .SYNOPSIS
        This is a light, generic, wrapper proceedure around 'Invoke-RestMethod' to handle
        multiple retries and error/exception handling.

        This function makes no assumptions around the versions of the API used, the resource
        being operated/actioned upon, the operation/method being performed, nor the content
        of the HTTP headers and body.

    .PARAMETER ApiUri
        The URI of the Azure DevOps API to be connected to. For example:

          https://dev.azure.com/someOrganizationName/_apis/

    .PARAMETER HttpMethod
        The HTTP method being used in the HTTP/REST request sent to the Azure DevOps API.

    .PARAMETER HttpHeaders
        The headers for the HTTP/REST request sent to the Azure DevOps API.

    .PARAMETER HttpBody
        The body for the HTTP/REST request sent to the Azure DevOps API. If performing a 'Post',
        'Put' or 'Patch' method/request, this will typically contain the JSON document of the resource.

    .PARAMETER RetryAttempts
        The number of times the method/request will attempt to be resent/retried if unsuccessful on the
        initial attempt.

        If any attempt is successful, the remaining attempts are ignored.

    .PARAMETER RetryIntervalMs
        The interval (in Milliseconds) between retry attempts.

    .EXAMPLE
        Invoke-AzDevOpsApiRestMethod -ApiUri 'YourApiUriHere' -HttpMethod 'Get' -HttpHeaders $YouHttpHeadersHashtableHere

        Submits a 'Get' request to the Azure DevOps API (relying on the 'ApiUri' value to determine what is being retrieved).

    .EXAMPLE
        Invoke-AzDevOpsApiRestMethod -ApiUri 'YourApiUriHere' -HttpMethod 'Patch' -HttpHeaders $YourHttpHeadersHashtableHere `
                                     -HttpBody $YourHttpBodyHere -RetryAttempts 3

        Submits a 'Patch' request to the Azure DevOps API with the supplied 'HttpBody' and will attempt to retry 3 times (4 in
        total, including the intitial attempt) if unsuccessful.
#>
function Invoke-AzDevOpsApiRestMethod
{
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSObject])]
    param
    (
        [Parameter(Mandatory=$true)]
        [Alias('Uri')]
        [System.String]
        $ApiUri,

        [Parameter(Mandatory=$true)]
        [ValidateSet('Get','Post','Patch','Put','Delete')]
        [System.String]
        [Alias('Method')]
        $HttpMethod,

        [Parameter(Mandatory=$true)]
        [ValidateScript( { Test-AzDevOpsApiHttpRequestHeader -HttpRequestHeader $_ -IsValid })]
        [Hashtable]
        [Alias('Headers','HttpRequestHeader')]
        $HttpHeaders,

        [Parameter()]
        [System.String]
        [Alias('Body')]
        $HttpBody,

        [Parameter()]
        [System.String]
        [Alias('ContentType')]
        [ValidateSet('application/json')]
        $HttpContentType = 'application/json',

        [Parameter()]
        [ValidateRange(0,5)]
        [Int32]
        $RetryAttempts = 5,

        [Parameter()]
        [ValidateRange(250,10000)]
        [Int32]
        $RetryIntervalMs = 250
    )

    $invokeRestMethodParameters = @{
        Uri         = $ApiUri
        Method      = $HttpMethod
        Headers     = $HttpHeaders
        Body        = $HttpBody
        ContentType = $HttpContentType
    }

    # Remove the 'Body' and 'ContentType' if not relevant to request
    if ($HttpMethod -in $('Get','Delete'))
    {
        $invokeRestMethodParameters.Remove('Body')
        $invokeRestMethodParameters.Remove('ContentType')
    }

    # Intially set this value to -1, as the first attempt does not want to be classed as a "RetryAttempt"
    $CurrentNoOfRetryAttempts = -1

    while ($CurrentNoOfRetryAttempts -lt $RetryAttempts)
    {
        try
        {
            return Invoke-RestMethod @invokeRestMethodParameters
        }
        catch
        {
            # Increment the number of retries attempted and obtain any exception message
            $CurrentNoOfRetryAttempts++
            $restMethodExceptionMessage = $_.Exception.Message

            # Wait before the next attempt/retry
            Start-Sleep -Milliseconds $RetryIntervalMs
        }
    }


    # If all retry attempts have failed, throw an exception
    $errorMessage = $script:localizedData.AzDevOpsApiRestMethodException -f $MyInvocation.MyCommand, $RetryAttempts, $restMethodExceptionMessage
    New-InvalidOperationException -Message $errorMessage

}
