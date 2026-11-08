( function () {

	// Unlike TrackballControls, it maintains the "up" direction object.up (+Y by default).
	//
	//    Orbit - left mouse / touch: one-finger move
	//    Zoom - middle mouse, or mousewheel / touch: two-finger spread or squish
	//    Pan - right mouse, or left mouse + ctrl/meta/shiftKey, or arrow keys / touch: two-finger move

	const _changeEvent = {
		type: 'change'
	};
	const _startEvent = {
		type: 'start'
	};
	const _endEvent = {
		type: 'end'
	};

	class OrbitControls extends THREE.EventDispatcher {

		constructor( object, domElement ) {

			super();
			if ( domElement === undefined ) console.warn( 'THREE.OrbitControls: The second parameter "domElement" is now mandatory.' );
			if ( domElement === document ) console.error( 'THREE.OrbitControls: "document" should not be used as the target "domElement". Please use "renderer.domElement" instead.' );
			this.object = object;
			this.domElement = domElement; // Set to false to disable this control

			this.enabled = true; // "target" sets the location of focus, where the object orbits around

			this.target = new THREE.Vector3(); // How far you can dolly in and out ( PerspectiveCamera only )

			this.minDistance = 0;
			this.maxDistance = Infinity; // How far you can zoom in and out ( OrthographicCamera only )

			this.minZoom = 0;
			this.maxZoom = Infinity; // How far you can orbit vertically, upper and lower limits.
			// Range is 0 to Math.PI radians.

			this.minPolarAngle = 0; // radians

			this.maxPolarAngle = Math.PI; // radians
			// How far you can orbit horizontally, upper and lower limits.
			// If set, the interval [ min, max ] must be a sub-interval of [ - 2 PI, 2 PI ], with ( max - min < 2 PI )

			this.minAzimuthAngle = - Infinity; // radians

			this.maxAzimuthAngle = Infinity; // radians
			// Set to true to enable damping (inertia)
			// If damping is enabled, you must call controls.update() in your animation loop

			this.enableDamping = false;
			this.dampingFactor = 0.05; // This option actually enables dollying in and out; left as "zoom" for backwards compatibility.
			// Set to false to disable zooming

			this.enableZoom = true;
			this.zoomSpeed = 1.0; // Set to false to disable rotating

			this.enableRotate = true;
			this.rotateSpeed = 1.0; // Set to false to disable panning

			// Rotação circular com 2 dedos (giro em compasso / twist multi-touch)
			this.enableTwistRotate = true;
			this.twistRotateSpeed = 1.15;

			this.enablePan = true;
			this.panSpeed = 1.0;
			this.screenSpacePanning = true; // if false, pan orthogonal to world-space direction camera.up

			this.keyPanSpeed = 7.0; // pixels moved per arrow key push
			// Set to true to automatically rotate around the target
			// If auto-rotate is enabled, you must call controls.update() in your animation loop

			this.autoRotate = false;
			this.autoRotateSpeed = 2.0; // 30 seconds per orbit when fps is 60
			// The four arrow keys

			this.keys = {
				LEFT: 'ArrowLeft',
				UP: 'ArrowUp',
				RIGHT: 'ArrowRight',
				BOTTOM: 'ArrowDown'
			}; // Mouse buttons

			this.mouseButtons = {
				LEFT: THREE.MOUSE.ROTATE,
				MIDDLE: THREE.MOUSE.DOLLY,
				RIGHT: THREE.MOUSE.PAN
			}; // Touch fingers

			this.touches = {
				ONE: THREE.TOUCH.ROTATE,
				TWO: THREE.TOUCH.DOLLY_PAN
			}; // for reset

			this.target0 = this.target.clone();
			this.position0 = this.object.position.clone();
			this.zoom0 = this.object.zoom; // the target DOM element for key events

			this._domElementKeyEvents = null; //
			// public methods
			//

			this.getPolarAngle = function () {

				return spherical.phi;

			};

			this.getAzimuthalAngle = function () {

				return spherical.theta;

			};

			this.listenToKeyEvents = function ( domElement ) {

				domElement.addEventListener( 'keydown', onKeyDown );
				this._domElementKeyEvents = domElement;

			};

			this.saveState = function () {

				scope.target0.copy( scope.target );
				scope.position0.copy( scope.object.position );
				scope.zoom0 = scope.object.zoom;

			};

			this.stopInertia = function () {

				sphericalDelta.set( 0, 0, 0 );
				panOffset.set( 0, 0, 0 );
				zoomDelta = 0;
				scale = 1;

			};

			this.reset = function () {

				scope.stopInertia();
				scope.target.copy( scope.target0 );
				scope.object.position.copy( scope.position0 );
				scope.object.zoom = scope.zoom0;
				scope.object.updateProjectionMatrix();
				scope.dispatchEvent( _changeEvent );
				scope.update();
				state = STATE.NONE;

			}; // this method is exposed, but perhaps it would be better if we can make it private...


			this.update = function () {

				const offset = new THREE.Vector3(); // so camera.up is the orbit axis

				const quat = new THREE.Quaternion().setFromUnitVectors( object.up, new THREE.Vector3( 0, 1, 0 ) );
				const quatInverse = quat.clone().invert();
				const lastPosition = new THREE.Vector3();
				const lastQuaternion = new THREE.Quaternion();
				const twoPI = 2 * Math.PI;
				let lastUpdateTime = ( typeof performance !== 'undefined' ? performance.now() : Date.now() ) - 16.667;

				return function update() {

					const now = typeof performance !== 'undefined' ? performance.now() : Date.now();
					const elapsedMs = Math.min( 64, Math.max( 0, now - lastUpdateTime ) );
					lastUpdateTime = now;
					const dtFrames = elapsedMs / 16.6667;
					const dampingAlpha = scope.enableDamping
						? ( 1 - Math.pow( Math.max( 0.001, 1 - scope.dampingFactor ), dtFrames ) )
						: 1;

					const position = scope.object.position;
					offset.copy( position ).sub( scope.target ); // rotate offset to "y-axis-is-up" space

					offset.applyQuaternion( quat ); // angle from z-axis around y-axis

					spherical.setFromVector3( offset );

					if ( scope.autoRotate && state === STATE.NONE ) {

						rotateLeft( getAutoRotationAngle() );

					}

					if ( scope.enableDamping ) {

						spherical.theta += sphericalDelta.theta * dampingAlpha;
						spherical.phi += sphericalDelta.phi * dampingAlpha;

					} else {

						spherical.theta += sphericalDelta.theta;
						spherical.phi += sphericalDelta.phi;

					} // restrict theta to be between desired limits


					let min = scope.minAzimuthAngle;
					let max = scope.maxAzimuthAngle;

					if ( isFinite( min ) && isFinite( max ) ) {

						if ( min < - Math.PI ) min += twoPI; else if ( min > Math.PI ) min -= twoPI;
						if ( max < - Math.PI ) max += twoPI; else if ( max > Math.PI ) max -= twoPI;

						if ( min <= max ) {

							spherical.theta = Math.max( min, Math.min( max, spherical.theta ) );

						} else {

							spherical.theta = spherical.theta > ( min + max ) / 2 ? Math.max( min, spherical.theta ) : Math.min( max, spherical.theta );

						}

					} // restrict phi to be between desired limits


					spherical.phi = Math.max( scope.minPolarAngle, Math.min( scope.maxPolarAngle, spherical.phi ) );
					spherical.makeSafe();

					if ( scope.enableDamping === true ) {

						if ( Math.abs( zoomDelta ) > 1e-7 ) {

							const stepZoom = zoomDelta * dampingAlpha;
							spherical.radius *= Math.exp( stepZoom );
							zoomDelta -= stepZoom;

						} else {

							zoomDelta = 0;

						}
						spherical.radius *= scale;

					} else {

						spherical.radius *= scale;
						zoomDelta = 0;

					}

					// restrict radius to be between desired limits e evita acúmulo de zoom além dos limites
					if ( spherical.radius <= scope.minDistance ) {

						spherical.radius = scope.minDistance;
						if ( zoomDelta < 0 ) zoomDelta = 0;

					} else if ( spherical.radius >= scope.maxDistance ) {

						spherical.radius = scope.maxDistance;
						if ( zoomDelta > 0 ) zoomDelta = 0;

					}

					// move target to panned location
					if ( scope.enableDamping === true ) {

						scope.target.addScaledVector( panOffset, dampingAlpha );

					} else {

						scope.target.add( panOffset );

					}

					offset.setFromSpherical( spherical ); // rotate offset back to "camera-up-vector-is-up" space

					offset.applyQuaternion( quatInverse );
					position.copy( scope.target ).add( offset );
					scope.object.lookAt( scope.target );

					if ( scope.enableDamping === true ) {

						const retain = 1 - dampingAlpha;
						sphericalDelta.theta *= retain;
						sphericalDelta.phi *= retain;
						panOffset.multiplyScalar( retain );

						if ( Math.abs( sphericalDelta.theta ) < 1e-7 ) sphericalDelta.theta = 0;
						if ( Math.abs( sphericalDelta.phi ) < 1e-7 ) sphericalDelta.phi = 0;
						if ( panOffset.lengthSq() < 1e-12 ) panOffset.set( 0, 0, 0 );

					} else {

						sphericalDelta.set( 0, 0, 0 );
						panOffset.set( 0, 0, 0 );

					}

					scale = 1; // update condition is:
					// min(camera displacement, camera rotation in radians)^2 > EPS
					// using small-angle approximation cos(x/2) = 1 - x^2 / 8

					if ( zoomChanged || lastPosition.distanceToSquared( scope.object.position ) > EPS || 8 * ( 1 - lastQuaternion.dot( scope.object.quaternion ) ) > EPS ) {

						scope.dispatchEvent( _changeEvent );
						lastPosition.copy( scope.object.position );
						lastQuaternion.copy( scope.object.quaternion );
						zoomChanged = false;
						return true;

					}

					return false;

				};

			}();

			this.dispose = function () {

				scope.domElement.removeEventListener( 'contextmenu', onContextMenu );
				scope.domElement.removeEventListener( 'pointerdown', onPointerDown );
				scope.domElement.removeEventListener( 'wheel', onMouseWheel );
				scope.domElement.removeEventListener( 'touchstart', onTouchStart );
				scope.domElement.removeEventListener( 'touchend', onTouchEnd );
				scope.domElement.removeEventListener( 'touchcancel', onTouchCancel );
				scope.domElement.removeEventListener( 'touchmove', onTouchMove );
				scope.domElement.ownerDocument.removeEventListener( 'pointermove', onPointerMove );
				scope.domElement.ownerDocument.removeEventListener( 'pointerup', onPointerUp );

				if ( scope._domElementKeyEvents !== null ) {

					scope._domElementKeyEvents.removeEventListener( 'keydown', onKeyDown );

				} //scope.dispatchEvent( { type: 'dispose' } ); // should this be added here?

			}; //
			// internals
			//


			const scope = this;
			const STATE = {
				NONE: - 1,
				ROTATE: 0,
				DOLLY: 1,
				PAN: 2,
				TOUCH_ROTATE: 3,
				TOUCH_PAN: 4,
				TOUCH_DOLLY_PAN: 5,
				TOUCH_DOLLY_ROTATE: 6
			};
			let state = STATE.NONE;
			const EPS = 0.000001; // current position in spherical coordinates

			const spherical = new THREE.Spherical();
			const sphericalDelta = new THREE.Spherical();
			let scale = 1;
			let zoomDelta = 0;
			const panOffset = new THREE.Vector3();
			let zoomChanged = false;
			const rotateStart = new THREE.Vector2();
			const rotateEnd = new THREE.Vector2();
			const rotateDelta = new THREE.Vector2();
			const panStart = new THREE.Vector2();
			const panEnd = new THREE.Vector2();
			const panDelta = new THREE.Vector2();
			const dollyStart = new THREE.Vector2();
			const dollyEnd = new THREE.Vector2();
			const dollyDelta = new THREE.Vector2();

			// Estado interno para rotação suave com 2 dedos (giro em compasso) e transições fluidas
			let twistStartAngle = 0;
			let twistAccumulated = 0;
			let twistUnlocked = false;
			let twistDirectionSign = 1;
			let lastTouchMoveTime = 0;
			const TWIST_MIN_DISTANCE = 28;
			const TWIST_UNLOCK_RAD = 0.02;

			function getAutoRotationAngle() {

				return 2 * Math.PI / 60 / 60 * scope.autoRotateSpeed;

			}

			function getZoomScale() {

				return Math.pow( 0.95, scope.zoomSpeed );

			}

			function rotateLeft( angle ) {

				sphericalDelta.theta -= angle;

			}

			function rotateUp( angle ) {

				sphericalDelta.phi -= angle;

			}

			const panLeft = function () {

				const v = new THREE.Vector3();
				return function panLeft( distance, objectMatrix ) {

					v.setFromMatrixColumn( objectMatrix, 0 ); // get X column of objectMatrix

					v.multiplyScalar( - distance );
					panOffset.add( v );

				};

			}();

			const panUp = function () {

				const v = new THREE.Vector3();
				return function panUp( distance, objectMatrix ) {

					if ( scope.screenSpacePanning === true ) {

						v.setFromMatrixColumn( objectMatrix, 1 );

					} else {

						v.setFromMatrixColumn( objectMatrix, 0 );
						v.crossVectors( scope.object.up, v );

					}

					v.multiplyScalar( distance );
					panOffset.add( v );

				};

			}(); // deltaX and deltaY are in pixels; right and down are positive


			const pan = function () {

				const offset = new THREE.Vector3();
				return function pan( deltaX, deltaY ) {

					const element = scope.domElement;

					if ( scope.object.isPerspectiveCamera ) {

						// perspective
						const position = scope.object.position;
						offset.copy( position ).sub( scope.target );
						let targetDistance = offset.length(); // half of the fov is center to top of screen

						targetDistance *= Math.tan( scope.object.fov / 2 * Math.PI / 180.0 ); // we use only clientHeight here so aspect ratio does not distort speed

						panLeft( 2 * deltaX * targetDistance / element.clientHeight, scope.object.matrix );
						panUp( 2 * deltaY * targetDistance / element.clientHeight, scope.object.matrix );

					} else if ( scope.object.isOrthographicCamera ) {

						// orthographic
						panLeft( deltaX * ( scope.object.right - scope.object.left ) / scope.object.zoom / element.clientWidth, scope.object.matrix );
						panUp( deltaY * ( scope.object.top - scope.object.bottom ) / scope.object.zoom / element.clientHeight, scope.object.matrix );

					} else {

						// camera neither orthographic nor perspective
						console.warn( 'WARNING: OrbitControls.js encountered an unknown camera type - pan disabled.' );
						scope.enablePan = false;

					}

				};

			}();

			function dollyOut( dollyScale ) {

				if ( scope.object.isPerspectiveCamera ) {

					if ( scope.enableDamping === true && dollyScale > 0 ) {

						zoomDelta -= Math.log( dollyScale );

					} else if ( dollyScale > 0 ) {

						scale /= dollyScale;

					}

				} else if ( scope.object.isOrthographicCamera ) {

					scope.object.zoom = Math.max( scope.minZoom, Math.min( scope.maxZoom, scope.object.zoom * dollyScale ) );
					scope.object.updateProjectionMatrix();
					zoomChanged = true;

				} else {

					console.warn( 'WARNING: OrbitControls.js encountered an unknown camera type - dolly/zoom disabled.' );
					scope.enableZoom = false;

				}

			}

			function dollyIn( dollyScale ) {

				if ( scope.object.isPerspectiveCamera ) {

					if ( scope.enableDamping === true && dollyScale > 0 ) {

						zoomDelta += Math.log( dollyScale );

					} else if ( dollyScale > 0 ) {

						scale *= dollyScale;

					}

				} else if ( scope.object.isOrthographicCamera ) {

					scope.object.zoom = Math.max( scope.minZoom, Math.min( scope.maxZoom, scope.object.zoom / dollyScale ) );
					scope.object.updateProjectionMatrix();
					zoomChanged = true;

				} else {

					console.warn( 'WARNING: OrbitControls.js encountered an unknown camera type - dolly/zoom disabled.' );
					scope.enableZoom = false;

				}

			} //
			// event callbacks - update the object state
			//


			function handleMouseDownRotate( event ) {

				rotateStart.set( event.clientX, event.clientY );

			}

			function handleMouseDownDolly( event ) {

				dollyStart.set( event.clientX, event.clientY );

			}

			function handleMouseDownPan( event ) {

				panStart.set( event.clientX, event.clientY );

			}

			function handleMouseMoveRotate( event ) {

				rotateEnd.set( event.clientX, event.clientY );
				rotateDelta.subVectors( rotateEnd, rotateStart ).multiplyScalar( scope.rotateSpeed );
				const element = scope.domElement;
				rotateLeft( 2 * Math.PI * rotateDelta.x / element.clientHeight ); // yes, height

				rotateUp( 2 * Math.PI * rotateDelta.y / element.clientHeight );
				rotateStart.copy( rotateEnd );
				if ( ! scope.enableDamping ) scope.update();

			}

			function handleMouseMoveDolly( event ) {

				dollyEnd.set( event.clientX, event.clientY );
				dollyDelta.subVectors( dollyEnd, dollyStart );

				if ( dollyDelta.y > 0 ) {

					dollyOut( getZoomScale() );

				} else if ( dollyDelta.y < 0 ) {

					dollyIn( getZoomScale() );

				}

				dollyStart.copy( dollyEnd );
				if ( ! scope.enableDamping ) scope.update();

			}

			function handleMouseMovePan( event ) {

				panEnd.set( event.clientX, event.clientY );
				panDelta.subVectors( panEnd, panStart ).multiplyScalar( scope.panSpeed );
				pan( panDelta.x, panDelta.y );
				panStart.copy( panEnd );
				if ( ! scope.enableDamping ) scope.update();

			}

			function handleMouseUp( ) { // no-op
			}

			function handleMouseWheel( event ) {

				if ( event.deltaY < 0 ) {

					dollyIn( getZoomScale() );

				} else if ( event.deltaY > 0 ) {

					dollyOut( getZoomScale() );

				}

				if ( ! scope.enableDamping ) scope.update();

			}

			function handleKeyDown( event ) {

				let needsUpdate = false;

				switch ( event.code ) {

					case scope.keys.UP:
						pan( 0, scope.keyPanSpeed );
						needsUpdate = true;
						break;

					case scope.keys.BOTTOM:
						pan( 0, - scope.keyPanSpeed );
						needsUpdate = true;
						break;

					case scope.keys.LEFT:
						pan( scope.keyPanSpeed, 0 );
						needsUpdate = true;
						break;

					case scope.keys.RIGHT:
						pan( - scope.keyPanSpeed, 0 );
						needsUpdate = true;
						break;

				}

				if ( needsUpdate ) {

					// prevent the browser from scrolling on cursor keys
					event.preventDefault();
					if ( ! scope.enableDamping ) scope.update();

				}

			}

			function handleTouchStartRotate( event ) {

				if ( event.touches.length === 1 ) {

					rotateStart.set( event.touches[ 0 ].pageX, event.touches[ 0 ].pageY );

				} else if ( event.touches.length >= 2 ) {

					const x = 0.5 * ( event.touches[ 0 ].pageX + event.touches[ 1 ].pageX );
					const y = 0.5 * ( event.touches[ 0 ].pageY + event.touches[ 1 ].pageY );
					rotateStart.set( x, y );

				}

			}

			function handleTouchStartPan( event ) {

				if ( event.touches.length === 1 ) {

					panStart.set( event.touches[ 0 ].pageX, event.touches[ 0 ].pageY );

				} else if ( event.touches.length >= 2 ) {

					const x = 0.5 * ( event.touches[ 0 ].pageX + event.touches[ 1 ].pageX );
					const y = 0.5 * ( event.touches[ 0 ].pageY + event.touches[ 1 ].pageY );
					panStart.set( x, y );

				}

			}

			function handleTouchStartDolly( event ) {

				if ( event.touches.length < 2 ) return;
				const dx = event.touches[ 0 ].pageX - event.touches[ 1 ].pageX;
				const dy = event.touches[ 0 ].pageY - event.touches[ 1 ].pageY;
				const distance = Math.max( 8, Math.hypot( dx, dy ) );
				dollyStart.set( 0, distance );

			}

			function handleTouchStartTwist( event ) {

				if ( event.touches.length < 2 ) return;
				const dx = event.touches[ 1 ].pageX - event.touches[ 0 ].pageX;
				const dy = event.touches[ 1 ].pageY - event.touches[ 0 ].pageY;
				twistStartAngle = Math.atan2( dy, dx );
				twistAccumulated = 0;
				twistUnlocked = false;
				// Preserva a coerência horária/anti-horária mesmo se a câmera estiver olhando de baixo para cima
				twistDirectionSign = ( spherical.phi > Math.PI * 0.58 ) ? - 1 : 1;

			}

			function handleTouchStartDollyPan( event ) {

				if ( scope.enableZoom ) handleTouchStartDolly( event );
				if ( scope.enablePan ) handleTouchStartPan( event );
				if ( scope.enableRotate && scope.enableTwistRotate ) handleTouchStartTwist( event );

			}

			function handleTouchStartDollyRotate( event ) {

				if ( scope.enableZoom ) handleTouchStartDolly( event );
				if ( scope.enableRotate ) {

					handleTouchStartRotate( event );
					if ( scope.enableTwistRotate ) handleTouchStartTwist( event );

				}

			}

			function handleTouchMoveRotate( event ) {

				if ( event.touches.length === 1 ) {

					rotateEnd.set( event.touches[ 0 ].pageX, event.touches[ 0 ].pageY );

				} else if ( event.touches.length >= 2 ) {

					const x = 0.5 * ( event.touches[ 0 ].pageX + event.touches[ 1 ].pageX );
					const y = 0.5 * ( event.touches[ 0 ].pageY + event.touches[ 1 ].pageY );
					rotateEnd.set( x, y );

				} else {

					return;

				}

				rotateDelta.subVectors( rotateEnd, rotateStart ).multiplyScalar( scope.rotateSpeed );
				const element = scope.domElement;
				// Calibração ergonômica para telas mobile em modo retrato sem distorcer telas largas
				const horizBasis = Math.max( 300, Math.min( element.clientHeight || 600, ( element.clientWidth || 400 ) * 1.35 ) );
				const vertBasis = Math.max( 300, element.clientHeight || 600 );

				rotateLeft( 2 * Math.PI * rotateDelta.x / horizBasis );
				rotateUp( 2 * Math.PI * rotateDelta.y / vertBasis );
				rotateStart.copy( rotateEnd );

			}

			function handleTouchMovePan( event ) {

				if ( event.touches.length === 1 ) {

					panEnd.set( event.touches[ 0 ].pageX, event.touches[ 0 ].pageY );

				} else if ( event.touches.length >= 2 ) {

					const x = 0.5 * ( event.touches[ 0 ].pageX + event.touches[ 1 ].pageX );
					const y = 0.5 * ( event.touches[ 0 ].pageY + event.touches[ 1 ].pageY );
					panEnd.set( x, y );

				} else {

					return;

				}

				panDelta.subVectors( panEnd, panStart ).multiplyScalar( scope.panSpeed );
				pan( panDelta.x, panDelta.y );
				panStart.copy( panEnd );

			}

			function handleTouchMoveDolly( event ) {

				if ( event.touches.length < 2 ) return;
				const dx = event.touches[ 0 ].pageX - event.touches[ 1 ].pageX;
				const dy = event.touches[ 0 ].pageY - event.touches[ 1 ].pageY;
				const distance = Math.max( 8, Math.hypot( dx, dy ) );
				dollyEnd.set( 0, distance );
				if ( dollyStart.y > 0 ) {

					dollyDelta.set( 0, Math.pow( dollyEnd.y / dollyStart.y, scope.zoomSpeed ) );
					dollyOut( dollyDelta.y );

				}
				dollyStart.copy( dollyEnd );

			}

			function handleTouchMoveTwist( event ) {

				if ( event.touches.length < 2 ) return;
				const dx = event.touches[ 1 ].pageX - event.touches[ 0 ].pageX;
				const dy = event.touches[ 1 ].pageY - event.touches[ 0 ].pageY;
				const distance = Math.hypot( dx, dy );
				const currentAngle = Math.atan2( dy, dx );

				// Evita instabilidade trigonométrica caso os dois dedos se encostem
				if ( distance < TWIST_MIN_DISTANCE ) {

					twistStartAngle = currentAngle;
					return;

				}

				let angleDelta = currentAngle - twistStartAngle;
				if ( angleDelta > Math.PI ) angleDelta -= 2 * Math.PI;
				if ( angleDelta < - Math.PI ) angleDelta += 2 * Math.PI;
				twistStartAngle = currentAngle;

				// Limita picos espúrios de hardware em troca de IDs capacitivos
				angleDelta = Math.max( - 0.25, Math.min( 0.25, angleDelta ) );

				if ( ! twistUnlocked ) {

					twistAccumulated += angleDelta;
					if ( Math.abs( twistAccumulated ) < TWIST_UNLOCK_RAD ) {

						return;

					}
					twistUnlocked = true;
					const excess = twistAccumulated - Math.sign( twistAccumulated ) * TWIST_UNLOCK_RAD;
					rotateLeft( - excess * scope.twistRotateSpeed * twistDirectionSign );
					return;

				}

				rotateLeft( - angleDelta * scope.twistRotateSpeed * twistDirectionSign );

			}

			function handleTouchMoveDollyPan( event ) {

				if ( scope.enableZoom ) handleTouchMoveDolly( event );
				if ( scope.enablePan ) handleTouchMovePan( event );
				if ( scope.enableRotate && scope.enableTwistRotate ) handleTouchMoveTwist( event );

			}

			function handleTouchMoveDollyRotate( event ) {

				if ( scope.enableZoom ) handleTouchMoveDolly( event );
				if ( scope.enableRotate ) {

					handleTouchMoveRotate( event );
					if ( scope.enableTwistRotate ) handleTouchMoveTwist( event );

				}

			}

			function handleTouchEnd( ) { // no-op
			} //
			// event handlers - FSM: listen for events and reset state
			//


			function onPointerDown( event ) {

				if ( scope.enabled === false ) return;

				switch ( event.pointerType ) {

					case 'mouse':
					case 'pen':
						onMouseDown( event );
						break;
        // TODO touch

				}

			}

			function onPointerMove( event ) {

				if ( scope.enabled === false ) return;

				switch ( event.pointerType ) {

					case 'mouse':
					case 'pen':
						onMouseMove( event );
						break;
        // TODO touch

				}

			}

			function onPointerUp( event ) {

				switch ( event.pointerType ) {

					case 'mouse':
					case 'pen':
						onMouseUp( event );
						break;
        // TODO touch

				}

			}

			function onMouseDown( event ) {

				// Prevent the browser from scrolling.
				event.preventDefault(); // Manually set the focus since calling preventDefault above
				// prevents the browser from setting it automatically.

				scope.domElement.focus ? scope.domElement.focus() : window.focus();
				let mouseAction;

				switch ( event.button ) {

					case 0:
						mouseAction = scope.mouseButtons.LEFT;
						break;

					case 1:
						mouseAction = scope.mouseButtons.MIDDLE;
						break;

					case 2:
						mouseAction = scope.mouseButtons.RIGHT;
						break;

					default:
						mouseAction = - 1;

				}

				switch ( mouseAction ) {

					case THREE.MOUSE.DOLLY:
						if ( scope.enableZoom === false ) return;
						handleMouseDownDolly( event );
						state = STATE.DOLLY;
						break;

					case THREE.MOUSE.ROTATE:
						if ( event.ctrlKey || event.metaKey || event.shiftKey ) {

							if ( scope.enablePan === false ) return;
							handleMouseDownPan( event );
							state = STATE.PAN;

						} else {

							if ( scope.enableRotate === false ) return;
							handleMouseDownRotate( event );
							state = STATE.ROTATE;

						}

						break;

					case THREE.MOUSE.PAN:
						if ( event.ctrlKey || event.metaKey || event.shiftKey ) {

							if ( scope.enableRotate === false ) return;
							handleMouseDownRotate( event );
							state = STATE.ROTATE;

						} else {

							if ( scope.enablePan === false ) return;
							handleMouseDownPan( event );
							state = STATE.PAN;

						}

						break;

					default:
						state = STATE.NONE;

				}

				if ( state !== STATE.NONE ) {

					scope.domElement.ownerDocument.addEventListener( 'pointermove', onPointerMove );
					scope.domElement.ownerDocument.addEventListener( 'pointerup', onPointerUp );
					scope.dispatchEvent( _startEvent );

				}

			}

			function onMouseMove( event ) {

				if ( scope.enabled === false ) return;
				event.preventDefault();

				switch ( state ) {

					case STATE.ROTATE:
						if ( scope.enableRotate === false ) return;
						handleMouseMoveRotate( event );
						break;

					case STATE.DOLLY:
						if ( scope.enableZoom === false ) return;
						handleMouseMoveDolly( event );
						break;

					case STATE.PAN:
						if ( scope.enablePan === false ) return;
						handleMouseMovePan( event );
						break;

				}

			}

			function onMouseUp( event ) {

				scope.domElement.ownerDocument.removeEventListener( 'pointermove', onPointerMove );
				scope.domElement.ownerDocument.removeEventListener( 'pointerup', onPointerUp );
				if ( scope.enabled === false ) return;
				handleMouseUp( event );
				scope.dispatchEvent( _endEvent );
				state = STATE.NONE;

			}

			function onMouseWheel( event ) {

				if ( scope.enabled === false || scope.enableZoom === false || state !== STATE.NONE && state !== STATE.ROTATE ) return;
				event.preventDefault();
				scope.dispatchEvent( _startEvent );
				handleMouseWheel( event );
				scope.dispatchEvent( _endEvent );

			}

			function onKeyDown( event ) {

				if ( scope.enabled === false || scope.enablePan === false ) return;
				handleKeyDown( event );

			}

			/**
			 * Sincroniza perfeitamente o estado dos controles com o número de dedos ativos na tela,
			 * evitando travamentos ("efeito estático") ao adicionar ou levantar um dos dedos (1 <-> 2 dedos).
			 */
			function syncTouchState( event ) {

				const touchCount = event.touches ? event.touches.length : 0;

				if ( touchCount === 1 ) {

					switch ( scope.touches.ONE ) {

						case THREE.TOUCH.ROTATE:
							if ( scope.enableRotate === false ) { state = STATE.NONE; return; }
							handleTouchStartRotate( event );
							state = STATE.TOUCH_ROTATE;
							break;

						case THREE.TOUCH.PAN:
							if ( scope.enablePan === false ) { state = STATE.NONE; return; }
							handleTouchStartPan( event );
							state = STATE.TOUCH_PAN;
							break;

						default:
							state = STATE.NONE;

					}

				} else if ( touchCount >= 2 ) {

					switch ( scope.touches.TWO ) {

						case THREE.TOUCH.DOLLY_PAN:
							if ( scope.enableZoom === false && scope.enablePan === false && ! ( scope.enableRotate && scope.enableTwistRotate ) ) {

								state = STATE.NONE;
								return;

							}
							handleTouchStartDollyPan( event );
							state = STATE.TOUCH_DOLLY_PAN;
							break;

						case THREE.TOUCH.DOLLY_ROTATE:
							if ( scope.enableZoom === false && scope.enableRotate === false ) {

								state = STATE.NONE;
								return;

							}
							handleTouchStartDollyRotate( event );
							state = STATE.TOUCH_DOLLY_ROTATE;
							break;

						default:
							state = STATE.NONE;

					}

				} else {

					state = STATE.NONE;

				}

			}

			function onTouchStart( event ) {

				if ( scope.enabled === false ) return;
				event.preventDefault(); // prevent scrolling

				const wasIdle = ( state === STATE.NONE );
				lastTouchMoveTime = typeof performance !== 'undefined' ? performance.now() : Date.now();
				syncTouchState( event );

				if ( wasIdle && state !== STATE.NONE ) {

					scope.dispatchEvent( _startEvent );

				}

			}

			function onTouchMove( event ) {

				if ( scope.enabled === false ) return;
				event.preventDefault(); // prevent scrolling

				const touchCount = event.touches ? event.touches.length : 0;
				if ( touchCount === 0 ) return;

				// Caso a contagem de dedos tenha mudado sem disparar touchstart/touchend no WebKit, ressincroniza sem saltos
				const isSingleState = ( state === STATE.TOUCH_ROTATE || state === STATE.TOUCH_PAN );
				const isMultiState = ( state === STATE.TOUCH_DOLLY_PAN || state === STATE.TOUCH_DOLLY_ROTATE );
				if ( ( isSingleState && touchCount >= 2 ) || ( isMultiState && touchCount === 1 ) || state === STATE.NONE ) {

					syncTouchState( event );
					return;

				}

				lastTouchMoveTime = typeof performance !== 'undefined' ? performance.now() : Date.now();

				switch ( state ) {

					case STATE.TOUCH_ROTATE:
						if ( scope.enableRotate === false ) return;
						handleTouchMoveRotate( event );
						if ( ! scope.enableDamping ) scope.update();
						break;

					case STATE.TOUCH_PAN:
						if ( scope.enablePan === false ) return;
						handleTouchMovePan( event );
						if ( ! scope.enableDamping ) scope.update();
						break;

					case STATE.TOUCH_DOLLY_PAN:
						if ( scope.enableZoom === false && scope.enablePan === false && ! ( scope.enableRotate && scope.enableTwistRotate ) ) return;
						handleTouchMoveDollyPan( event );
						if ( ! scope.enableDamping ) scope.update();
						break;

					case STATE.TOUCH_DOLLY_ROTATE:
						if ( scope.enableZoom === false && scope.enableRotate === false ) return;
						handleTouchMoveDollyRotate( event );
						if ( ! scope.enableDamping ) scope.update();
						break;

					default:
						state = STATE.NONE;

				}

			}

			function onTouchEnd( event ) {

				if ( scope.enabled === false ) return;
				handleTouchEnd( event );

				// Se ainda restar dedo(s) na tela (ex.: transição de 2 dedos -> 1 dedo), mantém navegação contínua!
				if ( event.touches && event.touches.length > 0 ) {

					syncTouchState( event );
					return;

				}

				// Se o usuário parou os dedos antes de soltar (> 95ms), reduz inércia residual para parada precisa;
				// caso solte em movimento (flick), mantém 100% da inércia suave.
				const now = typeof performance !== 'undefined' ? performance.now() : Date.now();
				if ( scope.enableDamping && ( now - lastTouchMoveTime ) > 95 ) {

					sphericalDelta.theta *= 0.25;
					sphericalDelta.phi *= 0.25;
					panOffset.multiplyScalar( 0.25 );
					zoomDelta *= 0.25;

				}

				scope.dispatchEvent( _endEvent );
				state = STATE.NONE;

			}

			function onTouchCancel( ) {

				if ( scope.enabled === false ) return;
				state = STATE.NONE;
				scope.dispatchEvent( _endEvent );

			}

			function onContextMenu( event ) {

				if ( scope.enabled === false ) return;
				event.preventDefault();

			} //


			scope.domElement.addEventListener( 'contextmenu', onContextMenu );
			scope.domElement.addEventListener( 'pointerdown', onPointerDown );
			scope.domElement.addEventListener( 'wheel', onMouseWheel, {
				passive: false
			} );
			scope.domElement.addEventListener( 'touchstart', onTouchStart, {
				passive: false
			} );
			scope.domElement.addEventListener( 'touchend', onTouchEnd );
			scope.domElement.addEventListener( 'touchcancel', onTouchCancel );
			scope.domElement.addEventListener( 'touchmove', onTouchMove, {
				passive: false
			} ); // force an update at start

			this.update();

		}

	} // This set of controls performs orbiting, dollying (zooming), and panning.
	// Unlike TrackballControls, it maintains the "up" direction object.up (+Y by default).
	// This is very similar to OrbitControls, another set of touch behavior
	//
	//    Orbit - right mouse, or left mouse + ctrl/meta/shiftKey / touch: two-finger rotate
	//    Zoom - middle mouse, or mousewheel / touch: two-finger spread or squish
	//    Pan - left mouse, or arrow keys / touch: one-finger move


	class MapControls extends OrbitControls {

		constructor( object, domElement ) {

			super( object, domElement );
			this.screenSpacePanning = false; // pan orthogonal to world-space direction camera.up

			this.mouseButtons.LEFT = THREE.MOUSE.PAN;
			this.mouseButtons.RIGHT = THREE.MOUSE.ROTATE;
			this.touches.ONE = THREE.TOUCH.PAN;
			this.touches.TWO = THREE.TOUCH.DOLLY_ROTATE;

		}

	}

	THREE.MapControls = MapControls;
	THREE.OrbitControls = OrbitControls;

} )();
