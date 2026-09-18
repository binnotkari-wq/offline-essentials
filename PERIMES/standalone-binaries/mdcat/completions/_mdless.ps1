
using namespace System.Management.Automation
using namespace System.Management.Automation.Language

Register-ArgumentCompleter -Native -CommandName 'mdless' -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)

    $commandElements = $commandAst.CommandElements
    $command = @(
        'mdless'
        for ($i = 1; $i -lt $commandElements.Count; $i++) {
            $element = $commandElements[$i]
            if ($element -isnot [StringConstantExpressionAst] -or
                $element.StringConstantType -ne [StringConstantType]::BareWord -or
                $element.Value.StartsWith('-') -or
                $element.Value -eq $wordToComplete) {
                break
        }
        $element.Value
    }) -join ';'

    $completions = @(switch ($command) {
        'mdless' {
            [CompletionResult]::new('--columns', 'columns', [CompletionResultType]::ParameterName, 'Maximum number of columns to use for output')
            [CompletionResult]::new('-c', 'c', [CompletionResultType]::ParameterName, 'Disable all colours and other styles')
            [CompletionResult]::new('--no-colour', 'no-colour', [CompletionResultType]::ParameterName, 'Disable all colours and other styles')
            [CompletionResult]::new('-l', 'l', [CompletionResultType]::ParameterName, 'Do not load remote resources like images')
            [CompletionResult]::new('--local', 'local', [CompletionResultType]::ParameterName, 'Do not load remote resources like images')
            [CompletionResult]::new('--fail', 'fail', [CompletionResultType]::ParameterName, 'Exit immediately if any error occurs processing an input file')
            [CompletionResult]::new('--detect-terminal', 'detect-terminal', [CompletionResultType]::ParameterName, 'Print detected terminal name and exit')
            [CompletionResult]::new('--ansi', 'ansi', [CompletionResultType]::ParameterName, 'Skip terminal detection and only use ANSI formatting')
            [CompletionResult]::new('-P', 'P ', [CompletionResultType]::ParameterName, 'Do not paginate output')
            [CompletionResult]::new('--no-pager', 'no-pager', [CompletionResultType]::ParameterName, 'Do not paginate output')
            [CompletionResult]::new('-p', 'p', [CompletionResultType]::ParameterName, 'Paginate the output of mdcat with a pager like less (default). Overrides an earlier --no-pager')
            [CompletionResult]::new('--paginate', 'paginate', [CompletionResultType]::ParameterName, 'Paginate the output of mdcat with a pager like less (default). Overrides an earlier --no-pager')
            [CompletionResult]::new('-h', 'h', [CompletionResultType]::ParameterName, 'Print help')
            [CompletionResult]::new('--help', 'help', [CompletionResultType]::ParameterName, 'Print help')
            [CompletionResult]::new('-V', 'V ', [CompletionResultType]::ParameterName, 'Print version')
            [CompletionResult]::new('--version', 'version', [CompletionResultType]::ParameterName, 'Print version')
            break
        }
    })

    $completions.Where{ $_.CompletionText -like "$wordToComplete*" } |
        Sort-Object -Property ListItemText
}
