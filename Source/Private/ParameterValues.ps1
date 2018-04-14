Update-TypeData -TypeName System.Management.Automation.InvocationInfo -MemberName ParameterValues -MemberType ScriptProperty -Value {
    $results = @{}
    foreach ($key in $this.MyCommand.Parameters.Keys) {
        if ($this.BoundParameters.ContainsKey($key)) {
            $results.$key = $this.BoundParameters.$key
        } elseif ($value = Get-Variable -Name $key -Scope 1 -ValueOnly -ErrorAction Ignore) {
            $results.$key = $value
        }
    }
    return $results
} -Force