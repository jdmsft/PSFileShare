# PSFileShare

File Share PowerShell Module

## Getting Started

These instructions will get you a copy of the project up and running on your local machine. See deployment for notes on how to deploy the project on a live system.

## Prerequisites

In order to use this module you need to use [PowerShell 7](https://github.com/PowerShell/PowerShell).


## How to use this module

Download this project and from PowerShell 7 console, run following cmdlets against project folder :

```
Import-Module .\PSFileShare
```

Some examples of what you can do with this module : 

```
# Create a file containing all shares (of the local computer)

New-FileShareFile -Path "D:\MySharesProject"

# Get file share infromation based on the content of the file created with New-FileShareFile

Get-FileShareInfos -InputFile "D:\MySharesProject\shares_COMPUTERNAME.json"-OutputPath "D:\MySharesProject"
```


## Built With

* [Visual Studio Code](https://code.visualstudio.com/)
* [GitHub](https://github.com/jdmsft)


## Versioning

We use [SemVer](http://semver.org/) for versioning. For the versions available, see the [tags on this repository](https://github.com/jdmsft/PSFileShare/tags). 

## Authors

* **Jessy DESLOGES** [@jdmsft](https://github.com/jdmsft)

See also the list of [contributors](https://github.com/jdmsft/PSFileShare/contributors) who participated in this project.