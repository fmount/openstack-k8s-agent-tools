package main

import (
	"context"
	"flag"
	"fmt"
	"os"
	"time"

	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/log/zap"
	"sigs.k8s.io/controller-runtime/pkg/manager"
)

// NovaReconciler reconciles Nova objects
type NovaReconciler struct {
	client.Client
	Scheme *runtime.Scheme
}

// Reconcile implements the reconciliation loop
func (r *NovaReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
	log := ctrl.LoggerFrom(ctx)
	log.Info("Starting reconciliation", "nova", req.NamespacedName)

	// Fetch the Nova instance
	var nova Nova
	if err := r.Get(ctx, req.NamespacedName, &nova); err != nil {
		if errors.IsNotFound(err) {
			log.Info("Nova resource not found, ignoring")
			return ctrl.Result{}, nil
		}
		log.Error(err, "Failed to get Nova resource")
		return ctrl.Result{}, err
	}

	// Check if the Nova instance is being deleted
	if nova.DeletionTimestamp != nil {
		return r.handleDeletion(ctx, &nova)
	}

	// Add finalizer if not present
	if !controllerutil.ContainsFinalizer(&nova, NovaFinalizer) {
		controllerutil.AddFinalizer(&nova, NovaFinalizer)
		if err := r.Update(ctx, &nova); err != nil {
			return ctrl.Result{}, err
		}
	}

	// Create or update resources
	if err := r.createOrUpdateService(ctx, &nova); err != nil {
		log.Error(err, "Failed to create or update Service")
		return ctrl.Result{RequeueAfter: time.Second * 30}, err
	}

	if err := r.createOrUpdateDeployment(ctx, &nova); err != nil {
		log.Error(err, "Failed to create or update Deployment")
		return ctrl.Result{RequeueAfter: time.Second * 30}, err
	}

	// Update status
	nova.Status.Conditions = []metav1.Condition{
		{
			Type:   "Ready",
			Status: metav1.ConditionTrue,
			Reason: "ReconciliationSuccessful",
		},
	}

	if err := r.Status().Update(ctx, &nova); err != nil {
		log.Error(err, "Failed to update Nova status")
		return ctrl.Result{}, err
	}

	log.Info("Successfully reconciled Nova", "nova", req.NamespacedName)
	return ctrl.Result{}, nil
}

// handleDeletion handles Nova resource deletion
func (r *NovaReconciler) handleDeletion(ctx context.Context, nova *Nova) (ctrl.Result, error) {
	log := ctrl.LoggerFrom(ctx)
	log.Info("Handling Nova deletion", "nova", nova.Name)

	// Perform cleanup logic here
	if err := r.cleanupResources(ctx, nova); err != nil {
		log.Error(err, "Failed to cleanup resources")
		return ctrl.Result{RequeueAfter: time.Second * 10}, err
	}

	// Remove finalizer
	controllerutil.RemoveFinalizer(nova, NovaFinalizer)
	if err := r.Update(ctx, nova); err != nil {
		return ctrl.Result{}, err
	}

	return ctrl.Result{}, nil
}

// createOrUpdateService creates or updates the Nova service
func (r *NovaReconciler) createOrUpdateService(ctx context.Context, nova *Nova) error {
	service := &corev1.Service{
		ObjectMeta: metav1.ObjectMeta{
			Name:      nova.Name + "-service",
			Namespace: nova.Namespace,
		},
		Spec: corev1.ServiceSpec{
			Selector: map[string]string{
				"app": nova.Name,
			},
			Ports: []corev1.ServicePort{
				{
					Port:       8774,
					TargetPort: intstr.FromInt(8774),
				},
			},
		},
	}

	if err := ctrl.SetControllerReference(nova, service, r.Scheme); err != nil {
		return err
	}

	return r.Client.Create(ctx, service)
}

// SetupWithManager sets up the controller with the Manager
func (r *NovaReconciler) SetupWithManager(mgr ctrl.Manager) error {
	return ctrl.NewControllerManagedBy(mgr).
		For(&Nova{}).
		Owns(&corev1.Service{}).
		Owns(&appsv1.Deployment{}).
		Complete(r)
}

func main() {
	var metricsAddr string
	var enableLeaderElection bool

	flag.StringVar(&metricsAddr, "metrics-bind-address", ":8080", "The address the metric endpoint binds to.")
	flag.BoolVar(&enableLeaderElection, "leader-elect", false, "Enable leader election for controller manager.")
	flag.Parse()

	ctrl.SetLogger(zap.New(zap.UseDevMode(true)))

	mgr, err := ctrl.NewManager(ctrl.GetConfigOrDie(), ctrl.Options{
		Scheme:             scheme,
		MetricsBindAddress: metricsAddr,
		Port:               9443,
		LeaderElection:     enableLeaderElection,
		LeaderElectionID:   "nova-operator",
	})
	if err != nil {
		fmt.Printf("Unable to start manager: %v\n", err)
		os.Exit(1)
	}

	if err = (&NovaReconciler{
		Client: mgr.GetClient(),
		Scheme: mgr.GetScheme(),
	}).SetupWithManager(mgr); err != nil {
		fmt.Printf("Unable to create controller: %v\n", err)
		os.Exit(1)
	}

	if err := mgr.Start(ctrl.SetupSignalHandler()); err != nil {
		fmt.Printf("Problem running manager: %v\n", err)
		os.Exit(1)
	}
}
