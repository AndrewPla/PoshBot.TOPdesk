function Get-TdIncident {
    <#
    .SYNOPSIS
        Returns Incidents. If you specify an operatoremail you can see all incidents assigned to them
    .PARAMETER TicketNumber
        The Number of the ticket that you want returned.
    .PARAMETER NumberofActions
        The number of actions that you want returned. by default no actions are returned.
    .PARAMETER OperatorEmail
        Specify the email of an operator who you want to see all assigned incidents. Only returns uncompleted incidents.
    .Example
    !Ticket I1902-123
    Returns a card for incident I1902-123
    .EXAMPLE
    !Ticket -op username@company.com
    Return list of all open tickets for the operator with the specified email
    .EXAMPLE
    !Ticket i1902-123 -actions 3
    Returns a card for i1902-123 and will also return the most recent 3 actions on the card
    #>
    [PoshBot.BotCommand(
        Aliases = ('tdticket', 'tdIncident')
    )]
    [cmdletbinding()]
    param(

        [parameter(position = 0)]
        [Alias('tn', 'ticket', 't')]
        [string]$TicketNumber,

        [Parameter()]
        [Alias('actions', 'actioncount', 'a')]
        [int]
        $NumberOfActions = 0,

        [Parameter(ParameterSetName = ('OperatorEmail'))]
        [Alias('op', 'o', 'operator')]
        [string]
        $OperatorEmail,

        [PoshBot.FromConfig('Credential')]
        [parameter(Mandatory)]
        [pscredential]
        $TOPdeskCredential,

        [PoshBot.FromConfig('Url')]
        [Parameter(Mandatory)]
        [string]
        $TOPdeskUrl,

        [Parameter(Mandatory)]
        [PoshBot.FromConfig('ApplicationPassword')]
        [Switch]
        $ApplicationPassword
    )

    # have to specify version for some reason
    Import-Module TOPdeskPS -RequiredVersion 0.1.0

    Connect-TdService -Credential $TOPdeskCredential -Url $TOPdeskUrl -ApplicationPassword:$ApplicationPassword -usertype 'Operator'

    if ($OperatorEmail) {
        $operator = Get-TdOperator -TOPdeskLoginName $OperatorEmail
        if ($Operator) {

            # Grab uncompleted tickets
            $Incidents = Get-TdIncident -OperatorId $Operator.id -Completed:$false -ResultSize 100


            $incidentText = ($incidents |
                    select-object Number, BriefDescription, @{name = 'Processing Status'; e = {$_.processingstatus.name}} |
                    Format-Table * |
                    out-string).trim()

            $TicketListResponse = @{
                Color = "#057AAB"
                Title = "$($operatorEmail)'s Tickets"
                Text  = $incidentText
            }
            New-PoshBotCardResponse @TicketListResponse

        }
        else {
            $operatorNotFound = @{
                Title = "Error: No Operator found"
                Text  = "There was no Operator found with email address $OperatorEmail"
                Type  = 'Error'
            }
            New-PoshBotCardResponse @operatorNotFound

        }
    }
    Else {
        $Ticket = Get-TdIncident -Number $TicketNumber
        if (-not $Ticket) {
            $errorCard = @{
                Title = "Error: No Tickets Found"
                Text  = "There were no incidents found with number $TicketNumber"
                Type  = 'Error'
            }
            New-PoshBotCardResponse @errorCard
            Return
        }


        #region Ticket Info
        # Hashtable containing values
        $TicketInfoObj = [pscustomobject]@{
            ProcessingStatus = $ticket.processingStatus.name
            Number           = $ticket.number
            Request          = $ticket.request
            BriefDescription = $ticket.briefDescription
            Caller           = "$($Ticket.caller.dynamicname) | $($ticket.callerbranch.name) "
            Category         = "$($ticket.category.name) | $($ticket.subcategory.name)"
            TimeSpent        = $ticket.timespent
            Operator         = "$($ticket.operatorGroup.name) | $($ticket.operator.name)"
        }

        $TicketCardResponseParams = @{
            Color = "#057AAB"
            Title = "Ticket: $($TicketNumber.tostring().ToUpper()) - $($TicketInfoObj.briefDescription)"
            Text  = ( $TicketInfoObj | Format-List * | out-string).trim()
        }

        New-PoshBotCardResponse @TicketCardResponseParams

        #endregion Ticket Info

        #TODO Construct an actions card

        $actions = $ticket | Get-TDIncidentAction

        # Blank hashtable to collect all of our actions


        # Only return the number of actions specified in $NumberofActions
        foreach ($action in ($actions | Select-Object -first $NumberOfActions) ) {
            if ($action.invisibleForCaller -like 'True') {
                $title = 'Invisible Action'
                $color = '#888888'
            }
            else {
                $title = 'Action'
                $color = '#057AAB'
            }


            $memoText = $action.memotext

            # We need to trim how long the response is sometimes I think
            if ($memotext.length -gt 750) {
                $memoText = $Memotext.Substring(0, 250)
            }


            $act = @{
                Title     = $title
                memoText  = $action.memoText
                entryDate = $action.entryDate
                operator  = $action.operator.name
                person    = $action.person
            }

            $actioncard = @{
                color = $color
                Title = $Title
                Text  = ([pscustomobject]$act |  Format-List * | out-string).trim()
            }

            # Now lets output our actions if we are supposed to.
            New-PoshBotCardResponse @actioncard
        }

    }

}


function Get-TdAsset {
    <#
    .SYNOPSIS
    Returns TOPdesk Assets.
    .PARAMETER NameFragment
    Part of the name of the an asset you want returned. No wildcards are required as this is just looking for the provided fragment.
    .EXAMPLE
    !Asset '10'
    Returns all assets with 10 in the name
    .EXAMPLE
    !Asset Printer
    Returns all assets with printer in the name
    #>
    [PoshBot.BotCommand(
        Aliases = ('tdasset', 'tda')
    )]
    [cmdletbinding()]
    param(
        [Parameter(position = 0)]
        [Alias('Name', 'n')]
        [string]
        $NameFragment,

        [PoshBot.FromConfig('Credential')]
        [parameter(Mandatory)]
        [pscredential]
        $TOPdeskCredential,

        [PoshBot.FromConfig('Url')]
        [Parameter(Mandatory)]
        [string]
        $TOPdeskUrl,

        [Parameter(Mandatory)]
        [PoshBot.FromConfig('ApplicationPassword')]
        [Switch]
        $ApplicationPassword
    )

    # have to specify version for some reason
    Import-Module TOPdeskPS -RequiredVersion 0.1.0

    Connect-TdService -Credential $TOPdeskCredential -Url $TOPdeskUrl -ApplicationPassword:$ApplicationPassword -usertype 'Operator'


    $Assets = Get-TdAsset -NameFragment $NameFragment

    foreach ($asset in $assets) {
        $assetDetail = $asset | Get-TdAssetDetail

        $actioncardParams = @{
            color = '#464775'
            Title = "$($asset.text) | $($Assetdetail.metadata.templatename) "
            Text  = ($assetDetail.data |  Format-List * | out-string).trim()
        }


        New-PoshBotCardResponse @actionCardParams
    }

}

Export-ModuleMember -function 'Get-TdIncident'
Export-ModuleMember -Function 'Get-TdAsset'
