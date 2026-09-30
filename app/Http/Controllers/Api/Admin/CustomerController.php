<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Http\Resources\Admin\CustomerResource;
use App\Models\Customer;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

/**
 * The admin mobile app's Customers API: the list, adding, editing and
 * removing a customer. Mirrors the web panel's Admin\CustomerController.
 */
class CustomerController extends Controller
{
    private const PER_PAGE = 20;

    public function index(Request $request): AnonymousResourceCollection
    {
        $this->authorizeView($request);

        $customers = Customer::query()
            ->when($request->string('search')->toString(), function ($query, $search) {
                $query->where(function ($query) use ($search) {
                    $query->where('name', 'like', "%{$search}%")
                        ->orWhere('phone', 'like', "%{$search}%")
                        ->orWhere('email', 'like', "%{$search}%");
                });
            })
            ->orderBy('name')
            ->paginate(self::PER_PAGE);

        return CustomerResource::collection($customers);
    }

    public function store(Request $request): JsonResponse
    {
        abort_unless($request->user()->can('customers.create'), 403, 'You do not have permission to add customers.');

        $customer = Customer::create($this->validated($request));

        return (new CustomerResource($customer))->response()->setStatusCode(201);
    }

    public function show(Request $request, Customer $customer): CustomerResource
    {
        $this->authorizeView($request);

        return new CustomerResource($customer);
    }

    public function update(Request $request, Customer $customer): CustomerResource
    {
        abort_unless($request->user()->can('customers.update'), 403, 'You do not have permission to edit customers.');

        $customer->update($this->validated($request));

        return new CustomerResource($customer);
    }

    public function destroy(Request $request, Customer $customer): JsonResponse
    {
        abort_unless($request->user()->can('customers.delete'), 403, 'You do not have permission to delete customers.');

        if ($customer->hires()->exists()) {
            return response()->json([
                'message' => "Customer \"{$customer->name}\" has existing hires and cannot be deleted.",
            ], 422);
        }

        $customer->delete();

        return response()->json(['message' => "Customer \"{$customer->name}\" was deleted."]);
    }

    private function validated(Request $request): array
    {
        return $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'phone' => ['required', 'string', 'max:30'],
            'email' => ['nullable', 'string', 'email', 'max:255'],
            'nic_passport' => ['nullable', 'string', 'max:100'],
            'address' => ['nullable', 'string'],
            'notes' => ['nullable', 'string'],
        ]);
    }

    private function authorizeView(Request $request): void
    {
        abort_unless($request->user()->can('customers.view'), 403, 'You do not have permission to view customers.');
    }
}
