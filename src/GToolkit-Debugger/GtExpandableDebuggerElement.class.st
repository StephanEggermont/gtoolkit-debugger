Class {
	#name : #GtExpandableDebuggerElement,
	#superclass : #GtDebuggerElement,
	#instVars : [
		'stackElement'
	],
	#category : #'GToolkit-Debugger'
}

{ #category : #'tools registry' }
GtExpandableDebuggerElement class >> registerToolsOn: registry [
	"Add ourselves to registry. See [Smalltalk tools]" 
	registry registerDebugger: self withRank: 1000.
]

{ #category : #accessing }
GtExpandableDebuggerElement class >> sessionClass [
	^ DebugSession 
]

{ #category : #opening }
GtExpandableDebuggerElement >> aboutToOpen [
	"Select the first non filtered context. This mean that we will ignore some methods 
	like halts or debug method to select the first interesting stack frame in the debugger."
	self setDebuggerToFirstNonFilteredContext.
]

{ #category : #callbacks }
GtExpandableDebuggerElement >> actOnDebugSessionChanged [
	| tabGroupElement cotainerElement |
	cotainerElement := BlElement new
		layout: BlLinearLayout horizontal;
		constraintsDo: [ :c |
			c horizontal matchParent.
			c vertical matchParent ].
	self buildPanesStructureIn: cotainerElement.
	
	tabGroupElement := self buildStackTabGroupForElement: cotainerElement.
	self 
		removeChildren;
		addChild: tabGroupElement.
	self updateStackPane.
]

{ #category : #callbacks }
GtExpandableDebuggerElement >> actOnSelectedContextChangedFor: aContext [
	| detailsTabGroupElement |
	detailsTabGroupElement := self buildDetailsElement.
	self detailsPane 
		removeChildren;
		addChild: detailsTabGroupElement as: #detailsElement
]

{ #category : #'building widgets' }
GtExpandableDebuggerElement >> buildContextVariablesElement [
	| contextVariablesElement |
	contextVariablesElement := self buildVariablesListElement.
	contextVariablesElement items: self contextVariables.
	contextVariablesElement userData
		at: #blocContainer
		put: #contextVariablesElement.
	^ contextVariablesElement
]

{ #category : #'building widgets' }
GtExpandableDebuggerElement >> buildDetailsElement [
	| detailsTabGroupElement |
	
	detailsTabGroupElement := self buildDetailsTabElement.
	detailsTabGroupElement viewModel 
		when: BrTabSelectedEvent 
		do: [ :event | event tab widgetDo: [ :aTab | self selectedDetailesTabName: aTab label asString ] ].

	(detailsTabGroupElement viewModel tabs 
		select: [ :aTabModel | aTabModel isAttachedToWidget ])
			detect: [ :aTabModel | aTabModel widget label asString = self selectedDetailesTabName ]
			ifFound: [ :aTabModel | aTabModel select ].
	^ detailsTabGroupElement
]

{ #category : #'building widgets' }
GtExpandableDebuggerElement >> buildDetailsTabElement [
	^ BrTabGroup new
		background: Color white;
		look: BrGlamorousTabGroupLook + BrShadowLook;
		addTab: (BrTab new
			look: BrGlamorousTabLook new;
			label: 'Variables';
			stencil: [ self buildContextVariablesElement ]);
		addTab: (BrTab new
			look: BrGlamorousTabLook new;
			label: 'Evaluator';
			stencil: [ self buildEvaluatorElement ]);
		addTab: (BrTab new
			look: BrGlamorousTabLook new;
			label: 'Watches';
			stencil: [ self buildWatchVariablesElement ])
]

{ #category : #'building widgets' }
GtExpandableDebuggerElement >> buildEvaluatorElement [
	| snippetCoder |
	snippetCoder := GtPharoSnippetCoder new
		forSource: 'self';
		context: self selectedContext;
		variableBindings: (GtSnippetBindings new
			receiver: self selectedContext receiver).
	^ snippetCoder asElement
]

{ #category : #'building widgets' }
GtExpandableDebuggerElement >> buildPaneElement [
	^ BlElement new
		constraintsDo: [ :c |
			c horizontal matchParent.
			c vertical matchParent.
			c linear weight: 1 ]
]

{ #category : #'building widgets' }
GtExpandableDebuggerElement >> buildPanesStructureIn: aContainer [
	| stackPane detailsPane |
	stackPane := self buildPaneElement
		constraintsDo: [ :c | c linear weight: 2 ];
		layout: BlLinearLayout horizontal.
	detailsPane := self buildPaneElement
		layout: BlFrameLayout new;
		padding: (BlInsets all: 10).
	
	aContainer 
		removeChildren;
		addChild: stackPane as: #stackPane;
		addChild: detailsPane as: #detailsPane.
]

{ #category : #'building widgets' }
GtExpandableDebuggerElement >> buildStackElement [
	| newStackElement |
	newStackElement := GtDebuggerExpandableStackElement new.
	newStackElement userData at: #blocContainer put: #stackElement.
	^ newStackElement
]

{ #category : #'building widgets' }
GtExpandableDebuggerElement >> buildStackTabGroupForElement: aStackElement [
	| tab tabGroup |
	tab := BrTab new.
	tab
		look: BrGlamorousTabWithoutBarLook;
		label: self session name;
		stencil: (BrValuableStencil from: aStackElement);
		padding:
			(BlInsets
				top: 15
				right: 0
				bottom: 15
				left: 10);
		toolbarStencil: [ | aToolbar |
			aToolbar := BrToolbar new.
			aToolbar look: BrGlamorousToolbarLook new.
			self buildStackToolbarActions
				do: [ :anAction | aToolbar addItem: anAction ].
			aToolbar ].
	tabGroup := BrTabGroup new.
	tabGroup
		look: (BrGlamorousTabGroupLook new headerBackground: BrGlamorousColors defaultHeaderBackgroundColor);
		addTab: tab;
		constraintsDo: [ :c | 
			c vertical matchParent.
			c horizontal matchParent ];
		addChild:
			(BlElement new
				constraintsDo: [ :c | 
					c ignoreByLayout.
					c horizontal matchParent.
					c vertical exact: 5 ];
				background: BrGlamorousColors errorBackgroundColor;
				yourself).
	^ tabGroup
]

{ #category : #'building widgets' }
GtExpandableDebuggerElement >> buildStackToolbarActions [
	<return: #Collection of: #BrButton>	
		
	| buttons toggle |
	buttons := (self actionsForPragmas: self stackDebuggingActionsPragmas) collect: [ :aDebuggingAction | 
		| actionButton |
		actionButton := BrButton new 
			look: BrGlamorousButtonWithIconLook;
			label: aDebuggingAction label; 
			action: [ 
				aDebuggingAction execute.
				aDebuggingAction needsUpdate ifTrue: [
					self updateStackWidget ] ].
			aDebuggingAction icon ifNotNil: [ :anIcon | 
				actionButton icon: aDebuggingAction icon asElement ].
			actionButton ].
		
	toggle := BrToggle new 
		look: BrGlamorousButtonWithIconLook + BrGlamorousToggleBackgroundLook;
		icon: BrGlamorousIcons edit asElement;
		when: BrToggleActivatedEvent do: [ :anEvent | 
			self stackElement enableVariableAnnotations ];
		when: BrToggleDeactivatedEvent do: [ :anEvent | 
			self stackElement disableVariableAnnotations ].
	buttons add: toggle.
	^ buttons
]

{ #category : #'building widgets' }
GtExpandableDebuggerElement >> buildVariablesListElement [
	| list |
	list := BrColumnedList new.
	list margin: (BlInsets top: 10).
	list addEventHandler: (GtPhlowListToSelectHandler new 
		transformation: [ :variableNode | variableNode value ]).
	list column
		title: 'Icon';
		width: 26;
		cellStencil: [ BlElement new 
			size: 26@22;
			layout: BlLinearLayout horizontal alignCenterLeft;
			labeled: 'Icon Container';
			padding: (BlInsets top: 3 left: 10 bottom: 3 right: 0) ];
		dataBinder: [ :aCellElement :aVariableNode |
			| anIconForm aVariableValue |
			anIconForm := [ 
				aVariableValue := aVariableNode rawValue.
				aVariableValue gtInspectorIcon ifNil: [ aVariableValue class systemIcon ]
			]	on: Error, Halt
				do: [ :error | self iconNamed: #smallWarningIcon ].
			aCellElement
				removeChildren;
				addChild: anIconForm asElement ].
	list column
		title: 'Variable';
		cellStencil: [ 
			BrLabel new
				look: (BrGlamorousLabelLook new foreground: Color black);
				hMatchParent;
				vFitContent;
				margin: (BlInsets top: 3 left: 10 bottom: 3 right: 0) ];
		dataBinder: [ :aCellElement :aVariableNode |
			aCellElement text: aVariableNode key asRopedText ].
	list column
		title: 'Value';
		cellStencil: [
			BrLabel new
				look: BrGlamorousLabelLook new;
				hMatchParent;
				vFitContent;
				margin: (BlInsets top: 3 left: 10 bottom: 3 right: 0) ];
		dataBinder: [ :aCellElement :aVariableNode |
			| aRawValue anErrorText|
			[ aRawValue := aVariableNode rawValue ] 
				on: Error 
				do: [ :error | anErrorText := aVariableNode errorMessage asRopedText foreground: Color red ].
			
			aCellElement text: ([ anErrorText ifNil: [ aRawValue gtDisplayString asRopedText ] ] 
					on: Error, Halt
					do: [ :error | error messageText asRopedText foreground: Color red ]) ].
	^ list
]

{ #category : #'building widgets' }
GtExpandableDebuggerElement >> buildWatchVariablesElement [
	| watchVariablesElement |
	watchVariablesElement := self buildVariablesListElement.
	watchVariablesElement items: {}.	"self watchVariables"
	^ watchVariablesElement
]

{ #category : #'building widgets' }
GtExpandableDebuggerElement >> contextVariables [
	| activeCoder |
	activeCoder := self selectedCoder.
	(activeCoder isNil or: [ activeCoder isDead ])
		ifTrue: [ ^ #() ].
	^ activeCoder debuggerVariableNodes
	
]

{ #category : #'accessing context' }
GtExpandableDebuggerElement >> currentContext [
	^ self selectedContext 
]

{ #category : #'accessing - elements' }
GtExpandableDebuggerElement >> detailsPane [
	^ self childNamed: #detailsPane
]

{ #category : #opening }
GtExpandableDebuggerElement >> filteredStack [
	^ (self session stackOfSize: 50 ) select: [ :aContext | 
		(aContext method hasPragmaNamed: #debuggerCompleteToSender) not ]
]

{ #category : #initialization }
GtExpandableDebuggerElement >> initialize [
	super initialize.
	self
		layout: BlLinearLayout horizontal;
		constraintsDo: [ :c |
			c horizontal matchParent.
			c vertical matchParent ].
	self userData at: #debuggerContainer put: #debuggerElement.
]

{ #category : #'accessing context' }
GtExpandableDebuggerElement >> selectedCoder [
	^ self stackElement selectedCoder
]

{ #category : #'accessing context' }
GtExpandableDebuggerElement >> selectedContext [
	^ self selectedCoder context
]

{ #category : #opening }
GtExpandableDebuggerElement >> setDebuggerToFirstNonFilteredContext [
	"I set the debugger to the first non filtered stack"

	| selection |
	selection := self selectedContext.
	(selection isNil or: [ selection method hasPragmaNamed: #debuggerCompleteToSender ]) ifFalse: [ ^ self ].
	
	 self filteredStack ifNotEmpty: [ :filteredStack |
		self selectedCoder expanded: false. "Do not expand the first context as another context is going to be expanded"
		self stackElement selectContext: filteredStack first ]
	
]

{ #category : #'building actions' }
GtExpandableDebuggerElement >> stackDebuggingActionsPragmas [
	^ #( gt2StackDebuggingAction )
]

{ #category : #'accessing - elements' }
GtExpandableDebuggerElement >> stackElement [
	^ self stackPane childNamed: #stackElement
]

{ #category : #'accessing - elements' }
GtExpandableDebuggerElement >> stackPane [
	^ self childNamed: #stackPane
]

{ #category : #updating }
GtExpandableDebuggerElement >> updateCoders [
	'TODO'
]

{ #category : #updating }
GtExpandableDebuggerElement >> updateDebugger [
	self updateStackWidget
]

{ #category : #updating }
GtExpandableDebuggerElement >> updateStackPane [
	| stackElement |
	stackElement := self buildStackElement.
	self stackPane 
		removeChildren;
		addChild: stackElement.
	self updateStackWidget.
]

{ #category : #updating }
GtExpandableDebuggerElement >> updateStackWidget [
	self stackElement updateForSession: debuggingSession.
]
